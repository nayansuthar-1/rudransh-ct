// Lets a member sign in with the email on their record, without an owner's
// invite (client request, 24 Sep 2026).
//
// POST { email }  →  200 { ok: true }, always.
//
// The login page calls this before asking Supabase Auth for a sign-in code.
// When an approved member has this email and no login yet, it makes one: an
// auth user (confirmed, no email sent) and a `member` profile linked to that
// member. The code itself is then sent by the normal OTP request, so only the
// person who reads that inbox gets in. It also confirms an invited login whose
// invite link was never opened, which would otherwise get no code.
//
// It answers the same whatever the email is — a member's, someone else's, or
// nobody's — so it cannot be used to find out who is a member.
//
// Deploy: supabase functions deploy member_sign_in --no-verify-jwt
//   (--no-verify-jwt: the caller is signed out by definition)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const emailPattern = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;

function ok(): Response {
  return new Response(JSON.stringify({ ok: true }), {
    status: 200,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return ok();

  try {
    const body = await req.json().catch(() => ({}));
    const email = String(body?.email ?? "").trim().toLowerCase();
    if (!emailPattern.test(email)) return ok();

    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );
    await prepareMemberLogin(admin, email);
  } catch (e) {
    // Logged for the office; the caller learns nothing either way.
    console.error("member_sign_in:", e);
  }
  return ok();
});

async function prepareMemberLogin(admin: SupabaseClient, email: string) {
  // A login made by an owner's invite before 25 Sep 2026 stays unconfirmed
  // until its email link is opened, and Supabase refuses a sign-in code to an
  // unconfirmed account. Confirm it; the code still goes only to this inbox.
  const { data: invited } = await admin
    .from("profiles")
    .select("user_id")
    .eq("email", email)
    .eq("is_active", true)
    .limit(1);
  if (invited && invited.length > 0) {
    await confirmLogin(admin, invited[0].user_id);
    return;
  }

  // The approved member with this email; the longest-standing one if a
  // person holds several memberships under one address. Emails are stored
  // lowercase (the column insists), so an exact match is right — and unlike
  // ilike, it does not read the "_" in an address as a wildcard.
  const { data: members } = await admin
    .from("members")
    .select("id, name")
    .eq("email", email)
    .neq("status", "pending")
    .order("join_date", { ascending: true })
    .limit(1);
  const member = members?.[0];
  if (!member) return;

  // Already has a login (invited, or signed in before): nothing to do.
  const { data: linked } = await admin
    .from("profiles")
    .select("user_id")
    .eq("member_id", member.id)
    .limit(1);
  if (linked && linked.length > 0) return;

  // The address belongs to someone who already has a login in another role
  // (the office, an agent): never turn that into a member login.
  const { data: taken } = await admin
    .from("profiles")
    .select("user_id")
    .eq("email", email)
    .limit(1);
  if (taken && taken.length > 0) return;

  let userId: string | undefined;
  let createdNow = false;
  const { data: created, error } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { role: "member" },
  });
  if (created?.user) {
    userId = created.user.id;
    createdNow = true;
  } else if (error) {
    // An auth account without a profile (a removed admin, an unfinished
    // invite): reuse it.
    userId = await findUserIdByEmail(admin, email);
  }
  if (!userId) return;

  const { error: profileError } = await admin.from("profiles").insert({
    user_id: userId,
    role: "member",
    name: member.name,
    email,
    member_id: member.id,
  });
  if (profileError && createdNow) {
    await admin.auth.admin.deleteUser(userId);
  }
}

async function confirmLogin(admin: SupabaseClient, userId: string) {
  const { data } = await admin.auth.admin.getUserById(userId);
  if (data?.user && !data.user.email_confirmed_at) {
    await admin.auth.admin.updateUserById(userId, { email_confirm: true });
  }
}

async function findUserIdByEmail(
  admin: SupabaseClient,
  email: string,
): Promise<string | undefined> {
  // Fine at this app's scale (hundreds of users).
  for (let page = 1; page <= 20; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 1000 });
    if (error) return undefined;
    const match = data.users.find((u) => u.email?.toLowerCase() === email);
    if (match) return match.id;
    if (data.users.length < 1000) return undefined;
  }
  return undefined;
}
