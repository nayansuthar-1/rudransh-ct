-- Release 2, Phase 10 (IMPLEMENTATION_PLAN §11.3–11.4): roles, access rules
-- and the tables later phases build on.
--
-- Owner and staff admins reach tables through row-level security. Agents and
-- members get no table policies at all: later phases give them SECURITY
-- DEFINER functions that filter to their own rows and mask Aadhaar.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.app_role as enum ('owner', 'staff', 'agent', 'member');
create type public.request_status as enum ('pending', 'approved', 'rejected');
create type public.payment_source as enum ('admin', 'agent', 'member');

-- ---------------------------------------------------------------------------
-- Profiles (replaces the admins table)
-- ---------------------------------------------------------------------------

create table public.profiles (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  role       public.app_role not null,
  name       text not null default '',
  email      text not null default '',
  agent_id   uuid unique references public.agents (id) on delete cascade,
  member_id  uuid unique references public.members (id) on delete cascade,
  is_active  boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Agents link to an agent record, members to a member record, admins to neither.
  constraint profiles_role_link check (
    case role
      when 'agent'  then agent_id is not null and member_id is null
      when 'member' then member_id is not null and agent_id is null
      else agent_id is null and member_id is null
    end
  )
);

create index profiles_role_idx on public.profiles (role);

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();

-- Everyone who is an admin today keeps every permission they have.
insert into public.profiles (user_id, role, name, email, created_at)
select user_id, 'owner', name, email, created_at from public.admins;

drop table public.admins;

-- ---------------------------------------------------------------------------
-- Role helpers
-- ---------------------------------------------------------------------------

-- The signed-in user's role, or null without an active profile. A deactivated
-- agent record or a member still pending approval also counts as no role.
create function public.my_role() returns public.app_role
language sql stable security definer set search_path = '' as $$
  select p.role
    from public.profiles p
    left join public.agents a on a.id = p.agent_id
    left join public.members m on m.id = p.member_id
   where p.user_id = (select auth.uid())
     and p.is_active
     and (p.role <> 'agent' or a.is_active)
     and (p.role <> 'member' or m.status <> 'pending');
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.my_role() in ('owner', 'staff'), false);
$$;

create function public.is_owner() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(public.my_role() = 'owner', false);
$$;

create function public.my_agent_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.agent_id from public.profiles p
   where p.user_id = (select auth.uid()) and public.my_role() = 'agent';
$$;

create function public.my_member_id() returns uuid
language sql stable security definer set search_path = '' as $$
  select p.member_id from public.profiles p
   where p.user_id = (select auth.uid()) and public.my_role() = 'member';
$$;

-- What the app needs after sign-in to pick the admin, agent or member screens.
create function public.my_profile()
returns table (role public.app_role, name text, email text, agent_id uuid, member_id uuid)
language sql stable security definer set search_path = '' as $$
  select p.role, p.name, p.email, p.agent_id, p.member_id
    from public.profiles p
   where p.user_id = (select auth.uid()) and p.role = public.my_role();
$$;

-- The Release 1 app reads `admins` at sign-in; keep that working.
create view public.admins with (security_invoker = true) as
select user_id, name, email, upper(role::text) as role, created_at
  from public.profiles
 where role in ('owner', 'staff') and is_active;

-- ---------------------------------------------------------------------------
-- Members: pending approval
-- ---------------------------------------------------------------------------

-- Pending members have no registration number yet.
alter table public.members alter column reg_no drop not null;
alter table public.members add constraint members_reg_no_required
  check (status = 'pending' or coalesce(reg_no, '') <> '');

-- Rebuilt so a null reg_no does not blank out the whole search text.
alter table public.members drop column search_text;
alter table public.members add column search_text text generated always as (
  lower(
    name || ' ' || coalesce(reg_no, '') || ' ' || father_or_husband_name || ' ' ||
    primary_phone || ' ' || alt_phone || ' ' || village || ' ' ||
    district || ' ' || waris_name
  )
) stored;

create index members_search_trgm on public.members
  using gin (search_text extensions.gin_trgm_ops);

-- Numbers are issued on approval, so rejected sign-ups never use one up.
create or replace function public.set_reg_no() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c text;
  prefix text;
begin
  if new.status = 'pending' then
    if tg_op = 'INSERT' then
      new.reg_no := null;
    end if;
    return new;
  end if;
  if coalesce(new.reg_no, '') <> '' or (tg_op = 'UPDATE' and old.status <> 'pending') then
    return new;
  end if;

  select code into c from public.yojnas where id = new.yojna_id;
  if c is null then
    raise exception 'Yojna % not found', new.yojna_id using errcode = '23503';
  end if;
  prefix := c || '-' || extract(year from now() at time zone 'Asia/Kolkata')::int;
  new.reg_no := prefix || '-' || public.zero_pad(public.next_number(prefix), 4);
  return new;
end $$;

drop trigger members_reg_no on public.members;
create trigger members_reg_no before insert or update of status on public.members
  for each row execute function public.set_reg_no();

-- ---------------------------------------------------------------------------
-- Cash handovers and commission
-- ---------------------------------------------------------------------------

-- An agent hands collected cash to the office; an admin confirms receiving it.
-- Deleting an agent with handovers is blocked: deactivate the agent instead.
create table public.cash_handovers (
  id           uuid primary key default gen_random_uuid(),
  agent_id     uuid not null references public.agents (id) on delete restrict,
  amount       numeric(12, 2) not null check (amount > 0),
  note         text not null default '',
  declared_at  timestamptz not null default now(),
  confirmed_by uuid references auth.users (id) on delete set null,
  confirmed_at timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index cash_handovers_agent_idx on public.cash_handovers (agent_id, declared_at desc);

create trigger cash_handovers_touch before update on public.cash_handovers
  for each row execute function public.touch_updated_at();

create table public.commission_payouts (
  id         uuid primary key default gen_random_uuid(),
  agent_id   uuid not null references public.agents (id) on delete restrict,
  month      date not null check (month = date_trunc('month', month)::date),
  amount     numeric(12, 2) not null check (amount >= 0),
  reference  text not null default '',
  paid_by    uuid references auth.users (id) on delete set null,
  paid_at    timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (agent_id, month)
);

create trigger commission_payouts_touch before update on public.commission_payouts
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Payments: approval, cancellation, closing link
-- ---------------------------------------------------------------------------

alter table public.payments
  add column source           public.payment_source not null default 'admin',
  -- Which closing this contribution pays for; drives the dues list (Phase 13).
  add column closing_case_id  uuid references public.closing_cases (id) on delete set null,
  add column approved_by      uuid references auth.users (id) on delete set null,
  add column approved_at      timestamptz,
  add column reject_reason    text not null default '',
  add column cancelled_by     uuid references auth.users (id) on delete set null,
  add column cancelled_at     timestamptz,
  add column cancel_reason    text not null default '',
  add column cash_handover_id uuid references public.cash_handovers (id) on delete set null;

create index payments_closing_case_idx on public.payments (closing_case_id)
  where closing_case_id is not null;
create index payments_cash_handover_idx on public.payments (cash_handover_id)
  where cash_handover_id is not null;

-- ---------------------------------------------------------------------------
-- Requests from agents and members
-- ---------------------------------------------------------------------------

-- An agent reports a death; an admin verifies it and creates the closing case.
create table public.closing_requests (
  id               uuid primary key default gen_random_uuid(),
  member_id        uuid not null references public.members (id) on delete cascade,
  agent_id         uuid references public.agents (id) on delete set null,
  reported_by      uuid default auth.uid() references auth.users (id) on delete set null,
  date_of_death    date not null,
  nominee_name     text not null default '',
  nominee_relation text not null default '',
  -- Death certificate photo on Cloudinary.
  certificate_url  text not null default '' check (certificate_url = '' or certificate_url ~ '^https://'),
  remarks          text not null default '',
  status           public.request_status not null default 'pending',
  decided_by       uuid references auth.users (id) on delete set null,
  decided_at       timestamptz,
  decision_note    text not null default '',
  closing_case_id  uuid references public.closing_cases (id) on delete set null,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create unique index closing_requests_one_pending on public.closing_requests (member_id)
  where status = 'pending';
create index closing_requests_status_idx on public.closing_requests (status, created_at desc);

create trigger closing_requests_touch before update on public.closing_requests
  for each row execute function public.touch_updated_at();

-- A change to a member's details, applied only when an admin approves it.
-- Aadhaar is left out until the privacy decision (IMPLEMENTATION_PLAN §7).
create table public.change_requests (
  id            uuid primary key default gen_random_uuid(),
  member_id     uuid not null references public.members (id) on delete cascade,
  requested_by  uuid default auth.uid() references auth.users (id) on delete set null,
  field         text not null check (field in (
                  'name', 'father_or_husband_name', 'waris_name', 'waris_relation',
                  'primary_phone', 'alt_phone', 'village', 'tehsil', 'district', 'pincode')),
  old_value     text not null default '',
  new_value     text not null default '',
  status        public.request_status not null default 'pending',
  decided_by    uuid references auth.users (id) on delete set null,
  decided_at    timestamptz,
  decision_note text not null default '',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create index change_requests_status_idx on public.change_requests (status, created_at desc);
create index change_requests_member_idx on public.change_requests (member_id);

create trigger change_requests_touch before update on public.change_requests
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Notifications and announcements
-- ---------------------------------------------------------------------------

create table public.notifications (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users (id) on delete cascade,
  type       text not null,
  title      text not null,
  body       text not null default '',
  -- In-app route to open, e.g. `/admin/approvals`.
  link       text not null default '',
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

create index notifications_user_idx on public.notifications (user_id, created_at desc);
create index notifications_unread_idx on public.notifications (user_id) where read_at is null;

create table public.announcements (
  id           uuid primary key default gen_random_uuid(),
  -- Null means every Yojna.
  yojna_id     uuid references public.yojnas (id) on delete cascade,
  title        text not null check (length(trim(title)) > 0),
  body         text not null default '',
  posted_by    uuid default auth.uid() references auth.users (id) on delete set null,
  published_at timestamptz not null default now(),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index announcements_published_idx on public.announcements (published_at desc);

create trigger announcements_touch before update on public.announcements
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Member lookup throttle (used by the public lookup page, Phase 15)
-- ---------------------------------------------------------------------------

create table public.lookup_attempts (
  id         bigint generated always as identity primary key,
  reg_no     text not null,
  succeeded  boolean not null,
  created_at timestamptz not null default now()
);

create index lookup_attempts_reg_no_idx on public.lookup_attempts (reg_no, created_at desc);

-- ---------------------------------------------------------------------------
-- Audit trail for the new tables
-- ---------------------------------------------------------------------------

-- profiles is keyed by user_id rather than id.
create or replace function public.write_audit_log() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  redact constant text[] := array['aadhaar'];
  o jsonb;
  n jsonb;
begin
  if tg_op <> 'INSERT' then o := to_jsonb(old) - redact; end if;
  if tg_op <> 'DELETE' then n := to_jsonb(new) - redact; end if;
  insert into public.audit_log (table_name, row_id, action, old_data, new_data)
  values (tg_table_name,
          coalesce(n ->> 'id', o ->> 'id', n ->> 'user_id', o ->> 'user_id')::uuid,
          tg_op, o, n);
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['profiles', 'cash_handovers', 'commission_payouts',
                           'closing_requests', 'change_requests', 'announcements'] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.write_audit_log()',
      t || '_audit', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on
  public.profiles, public.admins, public.cash_handovers, public.commission_payouts,
  public.closing_requests, public.change_requests, public.notifications,
  public.announcements, public.lookup_attempts
from anon, authenticated;

-- Profiles are created by the invite function / dashboard (service role).
grant select on public.profiles, public.admins to authenticated;
-- Agents and members create requests and handovers through functions (later phases).
grant select, update, delete
  on public.cash_handovers, public.closing_requests, public.change_requests
  to authenticated;
grant select, insert, update, delete
  on public.commission_payouts, public.announcements
  to authenticated;
-- Only marking a notification read; triggers create them.
grant select, update (read_at) on public.notifications to authenticated;
-- lookup_attempts: no access; only the lookup function touches it.

revoke all on function
  public.my_role(), public.is_owner(), public.my_agent_id(),
  public.my_member_id(), public.my_profile()
from public, anon;
grant execute on function
  public.my_role(), public.is_owner(), public.my_agent_id(),
  public.my_member_id(), public.my_profile()
to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security (IMPLEMENTATION_PLAN §11.3)
-- ---------------------------------------------------------------------------

do $$
declare t text;
begin
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases'] loop
    execute format('drop policy admin_all on public.%I', t);
  end loop;
end $$;
drop policy admin_read on public.audit_log;

alter table public.profiles           enable row level security;
alter table public.cash_handovers     enable row level security;
alter table public.commission_payouts enable row level security;
alter table public.closing_requests   enable row level security;
alter table public.change_requests    enable row level security;
alter table public.notifications      enable row level security;
alter table public.announcements      enable row level security;
alter table public.lookup_attempts    enable row level security;

do $$
declare t text;
begin
  -- Every table admins work with: owner and staff can read.
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases',
                           'profiles', 'cash_handovers', 'commission_payouts',
                           'closing_requests', 'change_requests', 'announcements'] loop
    execute format(
      'create policy admin_read on public.%I for select to authenticated
         using ((select public.is_admin()))', t);
  end loop;

  -- Schemes, agents and commission: only owners change them.
  foreach t in array array['yojnas', 'agents', 'commission_payouts'] loop
    execute format(
      'create policy owner_insert on public.%I for insert to authenticated
         with check ((select public.is_owner()))', t);
    execute format(
      'create policy owner_update on public.%I for update to authenticated
         using ((select public.is_owner())) with check ((select public.is_owner()))', t);
  end loop;

  -- Daily work: staff add and edit.
  foreach t in array array['members', 'payments', 'closing_cases', 'announcements'] loop
    execute format(
      'create policy admin_insert on public.%I for insert to authenticated
         with check ((select public.is_admin()))', t);
  end loop;
  foreach t in array array['members', 'payments', 'closing_cases', 'announcements',
                           'cash_handovers', 'closing_requests', 'change_requests'] loop
    execute format(
      'create policy admin_update on public.%I for update to authenticated
         using ((select public.is_admin())) with check ((select public.is_admin()))', t);
  end loop;

  -- Deleting is for owners only (staff cancel or mark inactive instead).
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases',
                           'cash_handovers', 'commission_payouts', 'closing_requests',
                           'change_requests'] loop
    execute format(
      'create policy owner_delete on public.%I for delete to authenticated
         using ((select public.is_owner()))', t);
  end loop;
end $$;

create policy admin_delete on public.announcements for delete to authenticated
  using ((select public.is_admin()));

create policy owner_read on public.audit_log for select to authenticated
  using ((select public.is_owner()));

-- Admins see and mark read their own notifications. Agents and members get
-- theirs through functions in Phase 14.
create policy own_read on public.notifications for select to authenticated
  using (user_id = (select auth.uid()) and (select public.is_admin()));
create policy own_update on public.notifications for update to authenticated
  using (user_id = (select auth.uid()) and (select public.is_admin()))
  with check (user_id = (select auth.uid()) and (select public.is_admin()));
