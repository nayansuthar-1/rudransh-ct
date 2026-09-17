-- Release 2, Phase 12 (IMPLEMENTATION_PLAN §11): agents add members and record
-- payments, which wait for an admin; admins approve, reject, cancel and move
-- members between agents.
--
-- Agents never touch tables directly (20260917000200_roles.sql). Every agent
-- function below filters to the caller's own members and hides Aadhaar.
-- Business rule failures raise P0001 with a message the app shows as is.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.payments
  add column cancel_requested_by   uuid references auth.users (id) on delete set null,
  add column cancel_requested_at   timestamptz,
  add column cancel_request_reason text not null default '';

create index payments_pending_idx on public.payments (created_at) where status = 'pending';
create index payments_cancel_request_idx on public.payments (cancel_requested_at)
  where cancel_requested_at is not null and cancelled_at is null;

-- Why a sign-up was rejected. A rejected sign-up stays as an inactive member
-- without a registration number, so money recorded against it keeps its member.
alter table public.members add column review_note text not null default '';

alter table public.members drop constraint members_reg_no_required;
alter table public.members add constraint members_reg_no_required
  check (status in ('pending', 'inactive') or coalesce(reg_no, '') <> '');

create or replace function public.set_reg_no() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c text;
  prefix text;
begin
  -- Numbers are issued on approval, so rejected sign-ups never use one up.
  if new.status = 'pending' then
    if tg_op = 'INSERT' then
      new.reg_no := null;
    end if;
    return new;
  end if;
  if coalesce(new.reg_no, '') <> '' then
    return new;
  end if;
  -- Rejecting a sign-up: stays without a number.
  if tg_op = 'UPDATE' and new.status = 'inactive' then
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

-- ---------------------------------------------------------------------------
-- Guards
-- ---------------------------------------------------------------------------

create function public.require_agent() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare a uuid := public.my_agent_id();
begin
  if a is null then
    raise exception 'Only an active agent can do this.' using errcode = '42501';
  end if;
  return a;
end $$;

create function public.require_admin() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_admin() then
    raise exception 'Only an admin can do this.' using errcode = '42501';
  end if;
end $$;

create function public.require_owner() returns void
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.is_owner() then
    raise exception 'Only an owner can do this.' using errcode = '42501';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Agent: members
-- ---------------------------------------------------------------------------

-- Schemes the agent may enrol members in.
create function public.agent_yojnas()
returns table (id uuid, name text, code text, contribution_amount numeric, registration_fee numeric)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select y.id, y.name, y.code, y.contribution_amount, y.registration_fee
    from public.yojnas y
    join public.agents ag on ag.id = a
   where y.is_active
     and (cardinality(ag.yojna_ids) = 0 or y.id = any (ag.yojna_ids))
   order by y.name;
end $$;

-- The agent's own members, newest first. Page with PostgREST `.range()`.
create function public.agent_members(
  p_query  text default null,
  p_status public.member_status default null
)
returns table (
  id uuid, yojna_id uuid, reg_no text, name text, father_or_husband_name text,
  jati text, gotra text, waris_name text, waris_relation text, gender public.gender,
  primary_phone text, alt_phone text, aadhaar_last4 text, village text, tehsil text,
  district text, pincode text, join_date date, status public.member_status,
  closing_date date, closing_group text, review_note text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select m.id, m.yojna_id, m.reg_no, m.name, m.father_or_husband_name,
         m.jati, m.gotra, m.waris_name, m.waris_relation, m.gender,
         m.primary_phone, m.alt_phone, right(m.aadhaar, 4), m.village, m.tehsil,
         m.district, m.pincode, m.join_date, m.status,
         m.closing_date, m.closing_group, m.review_note
    from public.members m
   where m.agent_id = a
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_status is null or m.status = p_status)
   order by m.join_date desc, m.created_at desc;
end $$;

-- New member, waiting for an admin. Returns its id.
create function public.agent_add_member(p_member jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  y uuid := nullif(p_member ->> 'yojna_id', '')::uuid;
  new_id uuid;
begin
  if y is null or not exists (select 1 from public.agent_yojnas() ay where ay.id = y) then
    raise exception 'You cannot enrol members in this Yojna.';
  end if;

  insert into public.members (
    yojna_id, name, father_or_husband_name, jati, gotra, waris_name, waris_relation,
    gender, primary_phone, alt_phone, aadhaar, village, tehsil, district, pincode,
    agent_id, join_date, status
  ) values (
    y,
    trim(coalesce(p_member ->> 'name', '')),
    trim(coalesce(p_member ->> 'father_or_husband_name', '')),
    trim(coalesce(p_member ->> 'jati', '')),
    trim(coalesce(p_member ->> 'gotra', '')),
    trim(coalesce(p_member ->> 'waris_name', '')),
    trim(coalesce(p_member ->> 'waris_relation', '')),
    coalesce(nullif(p_member ->> 'gender', '')::public.gender, 'male'),
    trim(p_member ->> 'primary_phone'),
    trim(coalesce(p_member ->> 'alt_phone', '')),
    trim(coalesce(p_member ->> 'aadhaar', '')),
    trim(coalesce(p_member ->> 'village', '')),
    trim(coalesce(p_member ->> 'tehsil', '')),
    trim(coalesce(p_member ->> 'district', '')),
    trim(coalesce(p_member ->> 'pincode', '')),
    a,
    coalesce(nullif(p_member ->> 'join_date', '')::date, public.today_ist()),
    'pending'
  ) returning id into new_id;
  return new_id;
end $$;

-- Phone and address only; name, nominee and Aadhaar need an admin.
create function public.agent_update_contact(p_member_id uuid, p_contact jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare a uuid := public.require_agent();
begin
  update public.members set
    primary_phone = trim(coalesce(p_contact ->> 'primary_phone', primary_phone)),
    alt_phone     = trim(coalesce(p_contact ->> 'alt_phone', alt_phone)),
    village       = trim(coalesce(p_contact ->> 'village', village)),
    tehsil        = trim(coalesce(p_contact ->> 'tehsil', tehsil)),
    district      = trim(coalesce(p_contact ->> 'district', district)),
    pincode       = trim(coalesce(p_contact ->> 'pincode', pincode))
  where id = p_member_id and agent_id = a;
  if not found then
    raise exception 'Member not found.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Agent: payments
-- ---------------------------------------------------------------------------

-- Records money the agent collected, waiting for an admin. The receipt number
-- is issued now so the agent can hand it to the member.
-- Returns { "id": ..., "receipt_no": ... }.
create function public.agent_record_payment(p_payment jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  mem record;
  k public.payment_kind := coalesce(nullif(p_payment ->> 'kind', '')::public.payment_kind, 'contribution');
  d date := coalesce(nullif(p_payment ->> 'date', '')::date, public.today_ist());
  cc uuid := nullif(p_payment ->> 'closing_case_id', '')::uuid;
  result record;
begin
  select m.id, m.yojna_id, m.status into mem
    from public.members m
   where m.id = nullif(p_payment ->> 'member_id', '')::uuid and m.agent_id = a;
  if not found then
    raise exception 'Member not found.';
  end if;
  if k = 'closingPayout' then
    raise exception 'Agents cannot record claim payouts.';
  end if;
  if mem.status = 'closed' then
    raise exception 'This membership is closed.';
  end if;
  if mem.status in ('pending', 'inactive') and k <> 'registration' then
    raise exception 'Only the registration fee can be collected before the member is approved.';
  end if;
  if d > public.today_ist() then
    raise exception 'The payment date cannot be in the future.';
  end if;
  if cc is not null and not exists (
    select 1 from public.closing_cases c where c.id = cc and c.yojna_id = mem.yojna_id
  ) then
    raise exception 'That closing is not in this member''s Yojna.';
  end if;

  insert into public.payments (
    receipt_no, member_id, yojna_id, amount, date, mode, status, kind, agent_id,
    reference, note, source, closing_case_id
  ) values (
    '', mem.id, mem.yojna_id, (p_payment ->> 'amount')::numeric, d,
    coalesce(nullif(p_payment ->> 'mode', '')::public.payment_mode, 'cash'),
    'pending', k, a,
    trim(coalesce(p_payment ->> 'reference', '')),
    trim(coalesce(p_payment ->> 'note', '')),
    'agent', cc
  ) returning id, receipt_no into result;

  return jsonb_build_object('id', result.id, 'receipt_no', result.receipt_no);
end $$;

-- Receipts the agent collected, newest first. Page with PostgREST `.range()`.
create function public.agent_payments(p_status public.payment_status default null)
returns table (
  id uuid, receipt_no text, member_id uuid, member_name text, member_reg_no text,
  yojna_id uuid, amount numeric, date date, mode public.payment_mode,
  status public.payment_status, kind public.payment_kind, reference text, note text,
  reject_reason text, cancelled_at timestamptz, cancel_reason text,
  cancel_requested_at timestamptz, cancel_request_reason text, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select p.id, p.receipt_no, p.member_id, m.name, m.reg_no,
         p.yojna_id, p.amount, p.date, p.mode,
         p.status, p.kind, p.reference, p.note,
         p.reject_reason, p.cancelled_at, p.cancel_reason,
         p.cancel_requested_at, p.cancel_request_reason, p.created_at
    from public.payments p
    join public.members m on m.id = p.member_id
   where p.agent_id = a
     and (p_status is null or p.status = p_status)
   order by p.date desc, p.created_at desc;
end $$;

create function public.agent_request_cancel(p_payment_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare a uuid := public.require_agent();
begin
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for cancelling.';
  end if;
  update public.payments set
    cancel_requested_by = (select auth.uid()),
    cancel_requested_at = now(),
    cancel_request_reason = trim(p_reason)
  where id = p_payment_id and agent_id = a
    and status <> 'failed' and cancelled_at is null and cancel_requested_at is null;
  if not found then
    raise exception 'This receipt cannot be cancelled, or a request is already open.';
  end if;
end $$;

-- Numbers for the agent's home page.
create function public.agent_summary()
returns table (
  active_members bigint, pending_members bigint,
  pending_payments bigint, pending_amount numeric, month_approved numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select
    (select count(*) from public.members m where m.agent_id = a and m.status = 'active'),
    (select count(*) from public.members m where m.agent_id = a and m.status = 'pending'),
    (select count(*) from public.payments p
      where p.agent_id = a and p.status = 'pending' and p.cancelled_at is null),
    (select coalesce(sum(p.amount), 0) from public.payments p
      where p.agent_id = a and p.status = 'pending' and p.cancelled_at is null),
    (select coalesce(sum(p.amount), 0) from public.payments p
      where p.agent_id = a and p.status = 'paid' and p.cancelled_at is null
        and p.date >= date_trunc('month', public.today_ist())::date);
end $$;

-- ---------------------------------------------------------------------------
-- Admin: approvals
-- ---------------------------------------------------------------------------

-- Returns the new registration number.
create function public.approve_member(p_member_id uuid) returns text
language plpgsql security definer set search_path = '' as $$
declare r text;
begin
  perform public.require_admin();
  update public.members set status = 'active', review_note = ''
   where id = p_member_id and status = 'pending'
  returning reg_no into r;
  if not found then
    raise exception 'This member is no longer waiting for approval.';
  end if;
  return r;
end $$;

create function public.reject_member(p_member_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for rejecting.';
  end if;
  update public.members set status = 'inactive', review_note = trim(p_reason)
   where id = p_member_id and status = 'pending';
  if not found then
    raise exception 'This member is no longer waiting for approval.';
  end if;
  update public.payments set status = 'failed', reject_reason = 'Member rejected: ' || trim(p_reason)
   where member_id = p_member_id and status = 'pending';
end $$;

create function public.approve_payment(p_payment_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  if exists (
    select 1 from public.payments p join public.members m on m.id = p.member_id
     where p.id = p_payment_id and m.status = 'pending'
  ) then
    raise exception 'Approve the member first.';
  end if;
  update public.payments set
    status = 'paid', approved_by = (select auth.uid()), approved_at = now(), reject_reason = ''
  where id = p_payment_id and status = 'pending' and cancelled_at is null;
  if not found then
    raise exception 'This payment is no longer waiting for approval.';
  end if;
end $$;

create function public.reject_payment(p_payment_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for rejecting.';
  end if;
  update public.payments set
    status = 'failed', reject_reason = trim(p_reason),
    approved_by = (select auth.uid()), approved_at = now()
  where id = p_payment_id and status = 'pending' and cancelled_at is null;
  if not found then
    raise exception 'This payment is no longer waiting for approval.';
  end if;
end $$;

-- Owners only. The receipt stays on record but leaves every total.
create function public.cancel_payment(p_payment_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_owner();
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for cancelling.';
  end if;
  update public.payments set
    cancelled_by = (select auth.uid()), cancelled_at = now(), cancel_reason = trim(p_reason)
  where id = p_payment_id and cancelled_at is null;
  if not found then
    raise exception 'This receipt is already cancelled.';
  end if;
end $$;

create function public.decline_cancel_request(p_payment_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  update public.payments set
    cancel_requested_by = null, cancel_requested_at = null, cancel_request_reason = ''
  where id = p_payment_id and cancel_requested_at is not null and cancelled_at is null;
  if not found then
    raise exception 'There is no open cancel request for this receipt.';
  end if;
end $$;

-- Moves members from one agent to another (all of them, or only
-- [p_member_ids]). Returns how many moved.
create function public.reassign_members(
  p_from_agent uuid,
  p_to_agent   uuid,
  p_member_ids uuid[] default null
) returns integer
language plpgsql security definer set search_path = '' as $$
declare n integer;
begin
  perform public.require_admin();
  if p_from_agent = p_to_agent then
    raise exception 'Choose a different agent.';
  end if;
  if not exists (select 1 from public.agents where id = p_to_agent and is_active) then
    raise exception 'Choose an active agent to move the members to.';
  end if;
  update public.members set agent_id = p_to_agent
   where agent_id = p_from_agent
     and (p_member_ids is null or id = any (p_member_ids));
  get diagnostics n = row_count;
  return n;
end $$;

-- ---------------------------------------------------------------------------
-- Totals: pending members and cancelled receipts do not count
-- ---------------------------------------------------------------------------

create or replace function public.members_per_yojna()
returns table (yojna_id uuid, member_count bigint)
language sql stable set search_path = '' as $$
  select yojna_id, count(*) from public.members
   where status <> 'pending' group by yojna_id;
$$;

create or replace function public.member_count_by_agent()
returns table (agent_id uuid, member_count bigint)
language sql stable set search_path = '' as $$
  select agent_id, count(*) from public.members
   where agent_id is not null and status <> 'pending' group by agent_id;
$$;

create or replace function public.payment_totals(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_mode     public.payment_mode default null,
  p_status   public.payment_status default null,
  p_kind     public.payment_kind default null,
  p_from     date default null,
  p_to       date default null,
  p_member_id uuid default null
) returns table (count bigint, paid numeric, pending numeric, failed numeric)
language sql stable set search_path = '' as $$
  select count(*),
         coalesce(sum(amount) filter (where status = 'paid' and cancelled_at is null), 0),
         coalesce(sum(amount) filter (where status = 'pending' and cancelled_at is null), 0),
         coalesce(sum(amount) filter (where status = 'failed' and cancelled_at is null), 0)
    from public.search_payments(p_yojna_id, p_query, p_mode, p_status, p_kind, p_from, p_to, p_member_id);
$$;

create or replace function public.monthly_collection(
  p_yojna_id uuid default null,
  p_months   int default 6
) returns table (month date, total numeric)
language sql stable set search_path = '' as $$
  with months as (
    select generate_series(
             date_trunc('month', public.today_ist()) - make_interval(months => p_months - 1),
             date_trunc('month', public.today_ist()),
             interval '1 month')::date as month
  )
  select mo.month, coalesce(sum(p.amount), 0)
    from months mo
    left join public.payments p
      on p.status = 'paid'
     and p.cancelled_at is null
     and p.date >= mo.month
     and p.date < (mo.month + interval '1 month')::date
     and (p_yojna_id is null or p.yojna_id = p_yojna_id)
   group by mo.month
   order by mo.month;
$$;

create or replace function public.collection_by_agent(p_yojna_id uuid default null)
returns table (agent_id uuid, total numeric)
language sql stable set search_path = '' as $$
  select agent_id, sum(amount) from public.payments
   where agent_id is not null and status = 'paid' and cancelled_at is null
     and (p_yojna_id is null or yojna_id = p_yojna_id)
   group by agent_id;
$$;

create or replace function public.dashboard_stats(p_yojna_id uuid default null)
returns table (
  total_members             bigint,
  active_members            bigint,
  inactive_members          bigint,
  closed_members            bigint,
  total_agents              bigint,
  active_agents             bigint,
  month_collection          numeric,
  previous_month_collection numeric,
  pending_claims            numeric
)
language sql stable set search_path = '' as $$
  with bounds as (
    select date_trunc('month', public.today_ist())::date as month_start,
           (date_trunc('month', public.today_ist()) - interval '1 month')::date as prev_start
  ),
  m as (
    select count(*) as total,
           count(*) filter (where status = 'active') as active,
           count(*) filter (where status = 'inactive') as inactive,
           count(*) filter (where status = 'closed') as closed
      from public.members
     where status <> 'pending'
       and (p_yojna_id is null or yojna_id = p_yojna_id)
  ),
  a as (
    select count(*) as total, count(*) filter (where is_active) as active
      from public.agents
  ),
  p as (
    select coalesce(sum(amount) filter (where date >= b.month_start), 0) as month_total,
           coalesce(sum(amount) filter (where date >= b.prev_start and date < b.month_start), 0) as prev_total
      from public.payments, bounds b
     where status = 'paid'
       and cancelled_at is null
       and date >= b.prev_start
       and (p_yojna_id is null or yojna_id = p_yojna_id)
  ),
  c as (
    select coalesce(sum(greatest(claim_amount - collected_amount, 0)), 0) as pending
      from public.closing_cases
     where pay_status <> 'paid'
       and (p_yojna_id is null or yojna_id = p_yojna_id)
  )
  select m.total, m.active, m.inactive, m.closed, a.total, a.active,
         p.month_total, p.prev_total, c.pending
    from m, a, p, c;
$$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function
  public.require_agent(), public.require_admin(), public.require_owner()
from public, anon, authenticated;

revoke all on function
  public.agent_yojnas(),
  public.agent_members(text, public.member_status),
  public.agent_add_member(jsonb),
  public.agent_update_contact(uuid, jsonb),
  public.agent_record_payment(jsonb),
  public.agent_payments(public.payment_status),
  public.agent_request_cancel(uuid, text),
  public.agent_summary(),
  public.approve_member(uuid),
  public.reject_member(uuid, text),
  public.approve_payment(uuid),
  public.reject_payment(uuid, text),
  public.cancel_payment(uuid, text),
  public.decline_cancel_request(uuid),
  public.reassign_members(uuid, uuid, uuid[])
from public, anon;

grant execute on function
  public.agent_yojnas(),
  public.agent_members(text, public.member_status),
  public.agent_add_member(jsonb),
  public.agent_update_contact(uuid, jsonb),
  public.agent_record_payment(jsonb),
  public.agent_payments(public.payment_status),
  public.agent_request_cancel(uuid, text),
  public.agent_summary(),
  public.approve_member(uuid),
  public.reject_member(uuid, text),
  public.approve_payment(uuid),
  public.reject_payment(uuid, text),
  public.cancel_payment(uuid, text),
  public.decline_cancel_request(uuid),
  public.reassign_members(uuid, uuid, uuid[])
to authenticated;
