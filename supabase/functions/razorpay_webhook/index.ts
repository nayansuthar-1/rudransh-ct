// Razorpay calls this when a payment is captured, so a payment is recorded
// even if the member closed the page before `razorpay_verify` ran
// (migration 20260927000300).
//
// POST <Razorpay event>, header X-Razorpay-Signature
// → 200 always once the signature checks out (Razorpay retries anything
//   else), 400 for a bad signature.
//
// Deploy: supabase functions deploy razorpay_webhook --no-verify-jwt
//   (--no-verify-jwt: Razorpay has no Supabase login; the signature is the
//   check)
// Secret: RAZORPAY_WEBHOOK_SECRET — the one typed into Razorpay's webhook
// settings (docs/RUNBOOK.md 1.8).

import { hmacHex, json, safeEqual, serviceClient } from "../_shared/razorpay.ts";

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  const secret = Deno.env.get("RAZORPAY_WEBHOOK_SECRET") ?? "";
  if (!secret) return json({ error: "Webhook is not set up." }, 503);

  // The signature covers the exact bytes Razorpay sent.
  const raw = await req.text();
  const expected = await hmacHex(secret, raw);
  const signature = req.headers.get("X-Razorpay-Signature") ?? "";
  if (!safeEqual(expected, signature)) {
    return json({ error: "Bad signature." }, 400);
  }

  try {
    const event = JSON.parse(raw);
    if (event?.event !== "payment.captured" && event?.event !== "order.paid") {
      return json({ ok: true, ignored: event?.event ?? "" });
    }
    const payment = event?.payload?.payment?.entity;
    const orderId = payment?.order_id as string | undefined;
    const paymentId = payment?.id as string | undefined;
    if (!orderId || !paymentId) return json({ ok: true, ignored: "no order" });

    const { error } = await serviceClient().rpc("record_online_payment", {
      p_order_id: orderId,
      p_gateway_payment_id: paymentId,
    });
    // An order this app never made (another integration on the same Razorpay
    // account) is not ours to record.
    if (error && !error.message.includes("Unknown order")) {
      console.error("record_online_payment failed:", error);
      return json({ error: "Try again." }, 500);
    }
    return json({ ok: true });
  } catch (e) {
    console.error("razorpay_webhook:", e);
    return json({ error: "Try again." }, 500);
  }
});
