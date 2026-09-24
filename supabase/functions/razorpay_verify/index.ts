// Confirms a payment the member just made in Razorpay's checkout, and records
// it as a Paid receipt (migration 20260927000300).
//
// POST { order_id, payment_id, signature }  (member's JWT)
// → 200 { receipt_no }  or 4xx/5xx { error }
//
// Razorpay signs order_id|payment_id with the key secret; a matching
// signature proves the payment is real, so no office approval is needed.
// The webhook records the same payment if this call never arrives, and
// `record_online_payment` makes the second of the two a no-op.
//
// Deploy: supabase functions deploy razorpay_verify
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (docs/RUNBOOK.md 1.8).

import {
  corsHeaders,
  hmacHex,
  HttpError,
  json,
  razorpayKeys,
  requireMember,
  safeEqual,
  serviceClient,
} from "../_shared/razorpay.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const { keySecret } = razorpayKeys();
    const admin = serviceClient();
    const { memberId } = await requireMember(admin, req);

    const body = await req.json().catch(() => ({}));
    const orderId = String(body?.order_id ?? "");
    const paymentId = String(body?.payment_id ?? "");
    const signature = String(body?.signature ?? "");
    if (!orderId || !paymentId || !signature) {
      throw new HttpError(400, "The payment details are incomplete.");
    }

    const expected = await hmacHex(keySecret, `${orderId}|${paymentId}`);
    if (!safeEqual(expected, signature)) {
      throw new HttpError(400, "The payment could not be verified.");
    }

    // The order must be this member's own.
    const { data: order } = await admin
      .from("online_payments")
      .select("member_id")
      .eq("order_id", orderId)
      .maybeSingle();
    if (!order || order.member_id !== memberId) {
      throw new HttpError(404, "Order not found.");
    }

    const { data, error } = await admin.rpc("record_online_payment", {
      p_order_id: orderId,
      p_gateway_payment_id: paymentId,
    });
    if (error) {
      console.error("record_online_payment failed:", error);
      throw new HttpError(500, "Paid, but the receipt could not be saved yet. It will appear shortly.");
    }
    const row = (data ?? [])[0] as { receipt_no?: string } | undefined;
    return json({ receipt_no: row?.receipt_no ?? "" });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error("razorpay_verify:", e);
    return json({ error: "Something went wrong. Try again." }, 500);
  }
});
