// Public membership lookup (IMPLEMENTATION_PLAN Phase 15). No login.
//
// POST { phone, aadhaar4, turnstile_token }
// → 200 { found: false }
//   200 { found: true, members: [{ reg_no, name, yojna_name, status,
//                                  join_date, contribution_amount,
//                                  dues_count, dues_amount }, ...],
//         member: <the first of members> }
//   or 4xx/5xx { error: "<readable message>" }
//
// One phone can hold more than one membership, so every match comes back.
// Each row carries `details`: the fields the member's certificate prints and
// their approved receipts (migration 20260927000100), passed through as is.
// `member` repeats the first for a page built before the lookup dropped the
// registration number.
//
// The database function `member_lookup` is granted to the service role only,
// so this function is the single way in and Turnstile is always checked first.
// It also records the attempt and locks a phone number after five wrong tries
// in 15 minutes.
//
// Deploy: supabase functions deploy member_lookup --no-verify-jwt
//   (--no-verify-jwt: the caller is signed out by definition)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// Required secret: TURNSTILE_SECRET_KEY (docs/RUNBOOK.md 1.7).

import { createClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

interface Input {
  phone: string;
  aadhaar4: string;
  turnstile_token: string;
}

async function readInput(req: Request): Promise<Input> {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    throw new HttpError(400, "Send the form as JSON.");
  }
  const text = (key: string) =>
    typeof body[key] === "string" ? (body[key] as string).trim() : "";

  const input: Input = {
    phone: text("phone").replace(/\D/g, ""),
    aadhaar4: text("aadhaar4").replace(/\D/g, ""),
    turnstile_token: text("turnstile_token"),
  };
  if (!/^\d{10}$/.test(input.phone)) {
    throw new HttpError(400, "Enter the 10-digit phone number.");
  }
  if (!/^\d{4}$/.test(input.aadhaar4)) {
    throw new HttpError(400, "Enter the last 4 digits of your Aadhaar.");
  }
  return input;
}

/// Fails closed: without a configured secret the lookup refuses to answer,
/// rather than quietly serving member data to anything that can send a POST.
async function checkTurnstile(token: string, ip: string | null): Promise<void> {
  const secret = Deno.env.get("TURNSTILE_SECRET_KEY");
  if (!secret) {
    console.error("TURNSTILE_SECRET_KEY is not set; refusing the lookup.");
    throw new HttpError(503, "Lookup is not available right now.");
  }
  if (!token) {
    throw new HttpError(400, "Please complete the check and try again.");
  }

  const form = new FormData();
  form.append("secret", secret);
  form.append("response", token);
  if (ip) form.append("remoteip", ip);

  let ok = false;
  try {
    const res = await fetch(
      "https://challenges.cloudflare.com/turnstile/v0/siteverify",
      { method: "POST", body: form },
    );
    const result = await res.json() as { success?: boolean };
    ok = result.success === true;
  } catch (e) {
    console.error("Turnstile verification failed to run:", e);
    throw new HttpError(503, "Lookup is not available right now.");
  }
  if (!ok) {
    throw new HttpError(400, "Please complete the check and try again.");
  }
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const input = await readInput(req);
    await checkTurnstile(
      input.turnstile_token,
      req.headers.get("cf-connecting-ip") ?? req.headers.get("x-forwarded-for"),
    );

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const { data, error } = await admin.rpc("member_lookup", {
      p_phone: input.phone,
      p_aadhaar4: input.aadhaar4,
    });

    if (error) {
      // P0001 carries a message written for the person reading it.
      if (error.code === "P0001") throw new HttpError(429, error.message);
      console.error("member_lookup failed:", error);
      throw new HttpError(500, "Could not check the records. Try again.");
    }

    const rows = (data ?? []) as unknown[];
    if (rows.length === 0) return json({ found: false });
    return json({ found: true, members: rows, member: rows[0] });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error("member_lookup:", e);
    return json({ error: "Something went wrong. Try again." }, 500);
  }
});
