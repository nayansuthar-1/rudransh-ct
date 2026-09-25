// Invites a person to the app and gives them a role (IMPLEMENTATION_PLAN
// Phase 11). An active owner may invite anyone; an active agent may invite
// only a member of their own (client decision, 25 Sep 2026).
//
// POST { role: "owner" | "staff" | "agent" | "member", email, name?,
//        agent_id? (role agent), member_id? (role member) }
// → 200 { user_id, email_sent }  or  4xx/5xx { error: "<readable message>" }
//   email_sent is false when the person already had an account, so no invite
//   email was needed. A failed send is a 502, never a 200.
//   The login is confirmed at once: the person signs in with an email code
//   straight away, whether or not they open the invite email.
//
// Deploy: supabase functions deploy invite_user   (docs/RUNBOOK.md 3)
// SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY are provided by Supabase.
// Optional secret SITE_URL (default https://rudransh-green.vercel.app).

import { createClient, type SupabaseClient } from "npm:@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const roles = ["owner", "staff", "agent", "member"] as const;
type Role = (typeof roles)[number];

/// Each role's own login page in the app (lib/core/router/routes.dart).
const loginPaths: Record<Role, string> = {
  owner: "/login",
  staff: "/login",
  agent: "/a",
  member: "/m",
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

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Use POST." }, 405);

  try {
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { persistSession: false, autoRefreshToken: false } },
    );

    const caller = await requireInviter(admin, req);
    const callerId = caller.userId;
    const input = await readInput(req);
    if (caller.agentId) await requireOwnMember(admin, caller.agentId, input);
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

    const siteUrl = Deno.env.get("SITE_URL") ?? "https://rudransh-green.vercel.app";
    const { data: invited, error: inviteError } = await admin.auth.admin.inviteUserByEmail(
      input.email,
      // `role` also picks the login page the invite email links to
      // (supabase/templates/invite.html): members /m, agents /a, office /login.
      { redirectTo: `${siteUrl}${loginPaths[input.role]}`, data: { role: input.role, invited_by: callerId } },
    );

    let userId = invited?.user?.id;
    let createdNow = true;
    // False when the person already had an account: no invite email goes out,
    // because they can already ask for a sign-in code with their email.
    let emailSent = true;

    if (inviteError) {
      // Two very different failures arrive here, and they must not be treated
      // alike. `email_exists` means the person already has an auth account (a
      // removed admin, an earlier invite) — reuse it, no email needed. Anything
      // else is a genuine send failure: SMTP not configured on the project, a
      // rate limit, a rejected sender. Hiding that reports "invite sent" when
      // nothing was sent, which is impossible to diagnose from the app.
      const alreadyExists =
        inviteError.code === "email_exists" || inviteError.status === 422;
      userId = alreadyExists
        ? await findUserIdByEmail(admin, input.email)
        : undefined;
      if (!userId) {
        throw new HttpError(
          502,
          `Could not send the invite: ${inviteError.message}`,
        );
      }
      createdNow = false;
      emailSent = false;
    }

    // An invited account stays unconfirmed until its email link is clicked,
    // and with sign-ups off Supabase refuses a sign-in code to an unconfirmed
    // account ("Signups not allowed"). The link also dies after a day, or when
    // a mail scanner opens it first. Confirm now, so the person signs in the
    // usual way — email, then the 6-digit code — and the email is only a
    // welcome note pointing at the login page (supabase/templates/invite.html).
    const { error: confirmError } = await admin.auth.admin.updateUserById(
      userId!,
      { email_confirm: true },
    );
    if (confirmError) {
      if (createdNow) await admin.auth.admin.deleteUser(userId!);
      throw new HttpError(500, `Could not activate the login: ${confirmError.message}`);
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

    // Keep the address on the member's record too, where the office and their
    // agent see it, unless the record already holds one.
    if (input.role === "member") {
      await admin
        .from("members")
        .update({ email: input.email })
        .eq("id", input.member_id!)
        .eq("email", "");
    }

    return json({ user_id: userId, email_sent: emailSent });
  } catch (e) {
    if (e instanceof HttpError) return json({ error: e.message }, e.status);
    console.error(e);
    return json({ error: "Something went wrong. Try again later." }, 500);
  }
});

/// The caller, if they may invite: an active owner (agentId null), or an
/// active agent whose agent record is active (agentId set).
async function requireInviter(
  admin: SupabaseClient,
  req: Request,
): Promise<{ userId: string; agentId: string | null }> {
  const token = (req.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "Sign in again.");

  // Same rules as public.my_role(): an active profile, and for an agent an
  // active agent record.
  const { data: profile } = await admin
    .from("profiles")
    .select("role, is_active, agent_id")
    .eq("user_id", data.user.id)
    .maybeSingle();
  if (profile?.is_active && profile.role === "owner") {
    return { userId: data.user.id, agentId: null };
  }
  if (profile?.is_active && profile.role === "agent" && profile.agent_id) {
    const { data: agent } = await admin
      .from("agents")
      .select("is_active")
      .eq("id", profile.agent_id)
      .maybeSingle();
    if (agent?.is_active) {
      return { userId: data.user.id, agentId: profile.agent_id };
    }
  }
  throw new HttpError(403, "Only an owner or an agent can invite people.");
}

/// An agent invites members only, and only their own.
async function requireOwnMember(
  admin: SupabaseClient,
  agentId: string,
  input: Input,
) {
  if (input.role !== "member" || !input.member_id) {
    throw new HttpError(403, "Agents can only invite their own members.");
  }
  const { data } = await admin
    .from("members")
    .select("agent_id")
    .eq("id", input.member_id)
    .maybeSingle();
  if (data?.agent_id !== agentId) {
    throw new HttpError(403, "Agents can only invite their own members.");
  }
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
