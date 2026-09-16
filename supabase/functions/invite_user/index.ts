// Invites a person to the app and gives them a role (IMPLEMENTATION_PLAN
// Phase 11). Only an active owner may call it.
//
// POST { role: "owner" | "staff" | "agent" | "member", email, name?,
//        agent_id? (role agent), member_id? (role member) }
// → 200 { user_id }  or  4xx/5xx { error: "<readable message>" }
//
// Deploy: supabase functions deploy invite_user   (docs/RUNBOOK.md 3)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// Optional secret SITE_URL (default https://rudransh-ct.pages.dev).

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const roles = ["owner", "staff", "agent", "member"] as const;
type Role = (typeof roles)[number];

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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const callerId = await requireOwner(admin, req);
    const input = await readInput(req);
    const name = await checkLink(admin, input);

    const lookup = admin.from("profiles").select("user_id").limit(1);
    const { data: existing } = input.agent_id
      ? await lookup.eq("agent_id", input.agent_id)
      : input.member_id
      ? await lookup.eq("member_id", input.member_id)
      : await lookup.eq("email", input.email);
    if (existing && existing.length > 0) {
      throw new HttpError(409, "This person already has app access.");
    }

    const siteUrl = Deno.env.get("SITE_URL") ?? "https://rudransh-ct.pages.dev";
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
      input.email,
      { redirectTo: siteUrl, data: { role: input.role, invited_by: callerId } },
    );

    let userId = invited?.user?.id;
    let createdNow = true;
    if (inviteError) {
      // Already has an auth account (for example a removed admin): reuse it.
      userId = await findUserIdByEmail(admin, input.email);
      createdNow = false;
      if (!userId) {
        throw new HttpError(400, `Could not send the invite: ${inviteError.message}`);
      }
    }

    const { error: profileError } = await admin.from("profiles").insert({
      user_id: userId,
      role: input.role,
      name: input.name || name,
      email: input.email,
      agent_id: input.role === "agent" ? input.agent_id : null,
      member_id: input.role === "member" ? input.member_id : null,
    });
    if (profileError) {
      if (createdNow && userId) await admin.auth.admin.deleteUser(userId);
      if (profileError.code === "23505") {
        throw new HttpError(409, "This person already has app access.");
      }
      throw new HttpError(500, `Could not save the login: ${profileError.message}`);
    }

    return json({ user_id: userId });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong. Try again later." }, 500);
  }
});

async function requireOwner(admin: SupabaseClient, req: Request): Promise<string> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Sign in again.");

  // Same rule as public.my_role() for owners: an active owner profile.
  const { data: profile } = await admin
    .from("profiles")
    .select("role, is_active")
    .eq("user_id", data.user.id)
    .maybeSingle();
  if (profile?.role !== "owner" || !profile.is_active) {
    throw new HttpError(403, "Only an owner can invite people.");
  }
  return data.user.id;
}

interface Input {
  role: Role;
  email: string;
  name: string;
  agent_id: string | null;
  member_id: string | null;
}

async function readInput(req: Request): Promise<Input> {
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    throw new HttpError(400, "Send a JSON body.");
  }
  const role = String(body.role ?? "") as Role;
  if (!roles.includes(role)) throw new HttpError(400, "Choose a valid role.");

  const email = String(body.email ?? "").trim().toLowerCase();
  if (!/^[^\s@,()]+@[^\s@,()]+\.[^\s@,()]+$/.test(email)) {
    throw new HttpError(400, "Enter a valid email address.");
  }

  const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  const agentId = body.agent_id ? String(body.agent_id) : null;
  const memberId = body.member_id ? String(body.member_id) : null;
  if ((agentId && !uuid.test(agentId)) || (memberId && !uuid.test(memberId))) {
    throw new HttpError(400, "Invalid record id.");
  }

  return {
    role,
    email,
    name: String(body.name ?? "").trim(),
    agent_id: agentId,
    member_id: memberId,
  };
}

/// Checks the agent or member record the login is for; returns its name.
async function checkLink(admin: SupabaseClient, input: Input): Promise<string> {
  if (input.role === "agent") {
    if (!input.agent_id) throw new HttpError(400, "Choose the agent to invite.");
    const { data } = await admin
      .from("agents")
      .select("name, is_active")
      .eq("id", input.agent_id)
      .maybeSingle();
    if (!data) throw new HttpError(404, "Agent not found.");
    if (!data.is_active) throw new HttpError(400, "Activate the agent before inviting them.");
    return data.name;
  }
  if (input.role === "member") {
    if (!input.member_id) throw new HttpError(400, "Choose the member to invite.");
    const { data } = await admin
      .from("members")
      .select("name, status")
      .eq("id", input.member_id)
      .maybeSingle();
    if (!data) throw new HttpError(404, "Member not found.");
    if (data.status === "pending") {
      throw new HttpError(400, "Approve the member before inviting them.");
    }
    return data.name;
  }
  if (input.agent_id || input.member_id) {
    throw new HttpError(400, "Admins are not linked to an agent or member.");
  }
  return "";
}

async function findUserIdByEmail(admin: SupabaseClient, email: string): Promise<string | undefined> {
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
