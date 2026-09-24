// Shared by the three Razorpay functions: CORS, JSON replies, the Razorpay
// API, and HMAC signature checks.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function serviceClient(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false, autoRefreshToken: false } },
  );
}

/// The Razorpay keys, or a 503: without them online payment is simply off.
export function razorpayKeys(): { keyId: string; keySecret: string } {
  const keyId = Deno.env.get("RAZORPAY_KEY_ID") ?? "";
  const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET") ?? "";
  if (!keyId || !keySecret) {
    throw new HttpError(503, "Online payment is not switched on yet.");
  }
  return { keyId, keySecret };
}

/// The signed-in member behind the request, from their JWT and an active
/// member profile. Anyone else is refused.
export async function requireMember(
  admin: SupabaseClient,
  req: Request,
): Promise<{ memberId: string; email: string }> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Sign in again.");

  const { data: profile } = await admin
    .from("profiles")
    .select("member_id, is_active")
    .eq("user_id", data.user.id)
    .eq("role", "member")
    .maybeSingle();
  if (!profile?.member_id || !profile.is_active) {
    throw new HttpError(403, "Only a member can pay online.");
  }
  return { memberId: profile.member_id as string, email: data.user.email ?? "" };
}

/// Lower-case hex HMAC-SHA256 of [message] under [secret].
export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

/// Compares two strings in time that does not depend on where they differ.
export function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}
