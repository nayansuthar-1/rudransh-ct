// Starts an online payment for a closing the signed-in member owes for
// (migration 20260927000300).
//
// POST { closing_case_id }  (member's JWT)
// → 200 { order_id, amount, currency, key_id, name, description, prefill }
//   or 4xx/5xx { error }
//
// The amount comes from the database (`online_payment_due`), never from the
// app. The order row is written before the member sees the checkout, so the
// webhook can always find it.
//
// Deploy: supabase functions deploy razorpay_order
// Secrets: RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET (docs/RUNBOOK.md 1.8).

import {
  corsHeaders,
  HttpError,
  json,
  razorpayKeys,
  requireMember,
  serviceClient,
} from "../_shared/razorpay.ts";

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const { keyId, keySecret } = razorpayKeys();
    const admin = serviceClient();
    const { memberId, email } = await requireMember(admin, req);

    const body = await req.json().catch(() => ({}));
    const closingCaseId = String(body?.closing_case_id ?? "");
    if (!uuid.test(closingCaseId)) throw new HttpError(400, "Choose what to pay for.");

    const { data: due, error: dueError } = await admin.rpc("online_payment_due", {
      p_member_id: memberId,
      p_closing_case_id: closingCaseId,
    });
    if (dueError) throw new HttpError(400, dueError.message);
    const amount = Number(due);

    const { data: member } = await admin
      .from("members")
      .select("name, reg_no, primary_phone, yojna_id")
      .eq("id", memberId)
      .single();
    if (!member) throw new HttpError(404, "Member not found.");

    const res = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Authorization": "Basic " + btoa(`${keyId}:${keySecret}`),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: Math.round(amount * 100), // paise
        currency: "INR",
        receipt: member.reg_no,
        notes: { member_id: memberId, closing_case_id: closingCaseId },
      }),
    });
    const order = await res.json();
    if (!res.ok || !order?.id) {
      console.error("razorpay order failed:", order);
      throw new HttpError(502, "Could not start the payment. Try again.");
    }

    const { error: insertError } = await admin.from("online_payments").insert({
      order_id: order.id,
      member_id: memberId,
      yojna_id: member.yojna_id,
      closing_case_id: closingCaseId,
      amount,
    });
    if (insertError) {
      console.error("online_payments insert failed:", insertError);
      throw new HttpError(500, "Could not start the payment. Try again.");
    }

    return json({
      order_id: order.id,
      amount: order.amount,
      currency: "INR",
      key_id: keyId,
      name: "Rudransh Charitable Trust",
      description: `${member.reg_no} · contribution`,
      prefill: { name: member.name, email, contact: member.primary_phone },
    });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error("razorpay_order:", e);
    return json({ error: "Something went wrong. Try again." }, 500);
  }
});
