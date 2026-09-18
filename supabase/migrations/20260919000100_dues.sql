-- Release 2, Phase 13 (IMPLEMENTATION_PLAN §11): dues per closing group,
-- contributions linked to a closing, and agents reporting a death.
--
-- Dues (§11.2): every active member of a Yojna who joined before a closing
-- group's first closing date owes one contribution, at the Yojna's
-- contribution amount, per closing group. A contribution counts for the group
-- when it is linked to any closing case in that group.
--
-- As in 20260918000100_agent_work.sql, agents only reach this data through
-- SECURITY DEFINER functions, and rule failures raise P0001 with a message
-- the app shows as is.

-- ---------------------------------------------------------------------------
-- Payments: a closing link must make sense
-- ---------------------------------------------------------------------------

create function public.check_payment_closing() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.closing_case_id is null then
    return new;
  end if;
  if new.kind <> 'contribution' then
    raise exception 'Only a contribution can be for a closing.';
  end if;
  if not exists (
    select 1 from public.closing_cases c
     where c.id = new.closing_case_id and c.yojna_id = new.yojna_id
  ) then
    raise exception 'That closing is not in this member''s Yojna.';
  end if;
  if exists (
    select 1 from public.closing_cases c
     where c.id = new.closing_case_id and c.member_id = new.member_id
  ) then
    raise exception 'A member cannot contribute to their own closing.';
  end if;
  return new;
end $$;

create trigger payments_check_closing
  before insert or update of closing_case_id, kind, yojna_id, member_id
  on public.payments
  for each row execute function public.check_payment_closing();

-- ---------------------------------------------------------------------------
-- Views (admins read them under their own access rules)
-- ---------------------------------------------------------------------------

-- Closing cases batched by Yojna and group label. Cases without a group label
-- raise no dues. [closing_case_id] is the group's first case, used when a
-- contribution is linked to the group as a whole.
create view public.closing_groups with (security_invoker = true) as
select c.yojna_id,
       c.closing_group,
       min(c.closing_date) as closing_date,
       count(*) as case_count,
       (array_agg(c.id order by c.closing_date, c.created_at, c.id))[1] as closing_case_id,
       array_agg(c.id) as case_ids
  from public.closing_cases c
 where c.closing_group <> ''
 group by c.yojna_id, c.closing_group;

-- One row per member per closing group they owe for. [due] is what is still
-- unpaid; [pending] is collected but not yet approved.
create view public.member_dues with (security_invoker = true) as
select g.yojna_id,
       g.closing_group,
       g.closing_date,
       g.closing_case_id,
       g.case_count,
       m.id as member_id,
       m.agent_id,
       y.contribution_amount as amount,
       coalesce(sum(p.amount) filter (where p.status = 'paid'), 0) as paid,
       coalesce(sum(p.amount) filter (where p.status = 'pending'), 0) as pending,
       greatest(y.contribution_amount
                - coalesce(sum(p.amount) filter (where p.status = 'paid'), 0), 0) as due
  from public.closing_groups g
  join public.yojnas y on y.id = g.yojna_id
  join public.members m
    on m.yojna_id = g.yojna_id
   and m.status = 'active'
   and m.join_date < g.closing_date
  left join public.payments p
    on p.member_id = m.id
   and p.kind = 'contribution'
   and p.cancelled_at is null
   and p.closing_case_id = any (g.case_ids)
 group by g.yojna_id, g.closing_group, g.closing_date, g.closing_case_id, g.case_count,
          m.id, m.agent_id, y.contribution_amount;

-- ---------------------------------------------------------------------------
-- Agent: dues
-- ---------------------------------------------------------------------------

-- Closing groups the agent's members owe for, newest first. Counts are
-- members: fully paid, collected but waiting for approval, and still due.
-- [to_collect] leaves out money already collected. Page with `.range()`.
create function public.agent_closing_groups()
returns table (
  yojna_id uuid, yojna_name text, closing_group text, closing_date date,
  closing_case_id uuid, case_count bigint, member_count bigint, paid_count bigint,
  pending_count bigint, due_count bigint, to_collect numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select d.yojna_id, y.name, d.closing_group, d.closing_date,
         d.closing_case_id, d.case_count, count(*),
         count(*) filter (where d.due = 0),
         count(*) filter (where d.due > 0 and d.pending > 0),
         count(*) filter (where d.due > 0 and d.pending = 0),
         coalesce(sum(greatest(d.due - d.pending, 0)), 0)
    from public.member_dues d
    join public.yojnas y on y.id = d.yojna_id
   where d.agent_id = a
   group by d.yojna_id, y.name, d.closing_group, d.closing_date, d.closing_case_id, d.case_count
   order by d.closing_date desc, d.closing_group;
end $$;

-- The agent's members in one closing group: still due first, then waiting
-- for approval, then paid.
create function public.agent_dues(p_yojna_id uuid, p_closing_group text)
returns table (
  member_id uuid, reg_no text, name text, primary_phone text, village text,
  closing_case_id uuid, closing_group text, closing_date date,
  amount numeric, paid numeric, pending numeric, due numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select m.id, m.reg_no, m.name, m.primary_phone, m.village,
         d.closing_case_id, d.closing_group, d.closing_date,
         d.amount, d.paid, d.pending, d.due
    from public.member_dues d
    join public.members m on m.id = d.member_id
   where d.agent_id = a
     and d.yojna_id = p_yojna_id
     and d.closing_group = p_closing_group
   order by case when d.due = 0 then 2 when d.pending > 0 then 1 else 0 end, m.name;
end $$;

-- Every closing group one of the agent's members owes for, oldest first.
-- The payment form uses it to pick which closing a contribution is for.
create function public.agent_member_dues(p_member_id uuid)
returns table (
  member_id uuid, closing_case_id uuid, closing_group text, closing_date date,
  amount numeric, paid numeric, pending numeric, due numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  if not exists (select 1 from public.members m where m.id = p_member_id and m.agent_id = a) then
    raise exception 'Member not found.';
  end if;
  return query
  select d.member_id, d.closing_case_id, d.closing_group, d.closing_date,
         d.amount, d.paid, d.pending, d.due
    from public.member_dues d
   where d.member_id = p_member_id
   order by d.closing_date, d.closing_group;
end $$;

-- ---------------------------------------------------------------------------
-- Agent: payments, now with the closing they are for
-- ---------------------------------------------------------------------------

create or replace function public.agent_record_payment(p_payment jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  mem record;
  k public.payment_kind := coalesce(nullif(p_payment ->> 'kind', '')::public.payment_kind, 'contribution');
  d date := coalesce(nullif(p_payment ->> 'date', '')::date, public.today_ist());
  cc uuid := nullif(p_payment ->> 'closing_case_id', '')::uuid;
  owed record;
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
  if cc is not null then
    if k <> 'contribution' then
      raise exception 'Only a contribution can be for a closing.';
    end if;
    if not exists (
      select 1 from public.closing_cases c where c.id = cc and c.yojna_id = mem.yojna_id
    ) then
      raise exception 'That closing is not in this member''s Yojna.';
    end if;
    select md.due, md.pending into owed
      from public.member_dues md
      join public.closing_cases c
        on c.id = cc and c.yojna_id = md.yojna_id and c.closing_group = md.closing_group
     where md.member_id = mem.id;
    if not found then
      raise exception 'This member does not owe for that closing.';
    end if;
    if owed.due - owed.pending <= 0 then
      raise exception 'This member''s contribution for that closing is already collected.';
    end if;
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

-- Adds the member's phone (for WhatsApp receipts) and the closing group, so
-- the return type changes and the function is recreated.
drop function public.agent_payments(public.payment_status);

create function public.agent_payments(p_status public.payment_status default null)
returns table (
  id uuid, receipt_no text, member_id uuid, member_name text, member_reg_no text,
  member_phone text, yojna_id uuid, amount numeric, date date, mode public.payment_mode,
  status public.payment_status, kind public.payment_kind, reference text, note text,
  closing_case_id uuid, closing_group text,
  reject_reason text, cancelled_at timestamptz, cancel_reason text,
  cancel_requested_at timestamptz, cancel_request_reason text, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select p.id, p.receipt_no, p.member_id, m.name, m.reg_no,
         m.primary_phone, p.yojna_id, p.amount, p.date, p.mode,
         p.status, p.kind, p.reference, p.note,
         p.closing_case_id, c.closing_group,
         p.reject_reason, p.cancelled_at, p.cancel_reason,
         p.cancel_requested_at, p.cancel_request_reason, p.created_at
    from public.payments p
    join public.members m on m.id = p.member_id
    left join public.closing_cases c on c.id = p.closing_case_id
   where p.agent_id = a
     and (p_status is null or p.status = p_status)
   order by p.date desc, p.created_at desc;
end $$;

-- ---------------------------------------------------------------------------
-- Agent: reporting a death
-- ---------------------------------------------------------------------------

-- The certificate is uploaded to Cloudinary first; only its URL is stored.
-- Returns the request id.
create function public.agent_request_closing(p_request jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  mem record;
  d date := nullif(p_request ->> 'date_of_death', '')::date;
  url text := trim(coalesce(p_request ->> 'certificate_url', ''));
  new_id uuid;
begin
  select m.id, m.status, m.join_date into mem
    from public.members m
   where m.id = nullif(p_request ->> 'member_id', '')::uuid and m.agent_id = a;
  if not found then
    raise exception 'Member not found.';
  end if;
  if mem.status <> 'active' then
    raise exception 'Only an active member''s death can be reported.';
  end if;
  if d is null then
    raise exception 'Enter the date of death.';
  end if;
  if d > public.today_ist() then
    raise exception 'The date of death cannot be in the future.';
  end if;
  if d < mem.join_date then
    raise exception 'The date of death is before the member joined.';
  end if;
  if url !~ '^https://res\.cloudinary\.com/' then
    raise exception 'Upload the death certificate.';
  end if;
  if exists (
    select 1 from public.closing_requests r where r.member_id = mem.id and r.status = 'pending'
  ) then
    raise exception 'A report for this member is already waiting for the office.';
  end if;

  insert into public.closing_requests (
    member_id, agent_id, date_of_death, nominee_name, nominee_relation,
    certificate_url, remarks
  ) values (
    mem.id, a, d,
    trim(coalesce(p_request ->> 'nominee_name', '')),
    trim(coalesce(p_request ->> 'nominee_relation', '')),
    url,
    trim(coalesce(p_request ->> 'remarks', ''))
  ) returning id into new_id;
  return new_id;
end $$;

-- Deaths the agent reported, newest first.
create function public.agent_closing_requests()
returns table (
  id uuid, member_id uuid, member_name text, member_reg_no text, date_of_death date,
  nominee_name text, nominee_relation text, certificate_url text, remarks text,
  status public.request_status, decision_note text, closing_case_id uuid,
  created_at timestamptz, decided_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select r.id, r.member_id, m.name, m.reg_no, r.date_of_death,
         r.nominee_name, r.nominee_relation, r.certificate_url, r.remarks,
         r.status, r.decision_note, r.closing_case_id,
         r.created_at, r.decided_at
    from public.closing_requests r
    join public.members m on m.id = r.member_id
   where r.agent_id = a
   order by r.created_at desc;
end $$;

-- ---------------------------------------------------------------------------
-- Admin: deciding on a reported death
-- ---------------------------------------------------------------------------

-- Creates the closing case from the report (which marks the member closed)
-- and returns its id. The claim amount defaults to the Yojna's.
create function public.approve_closing_request(
  p_request_id    uuid,
  p_closing_group text,
  p_claim_amount  numeric default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  req record;
  case_id uuid;
begin
  perform public.require_admin();
  if coalesce(trim(p_closing_group), '') = '' then
    raise exception 'Enter the closing group.';
  end if;

  select r.id, r.member_id, r.date_of_death, r.nominee_name, r.remarks,
         m.yojna_id, y.claim_amount
    into req
    from public.closing_requests r
    join public.members m on m.id = r.member_id
    join public.yojnas y on y.id = m.yojna_id
   where r.id = p_request_id and r.status = 'pending'
     for update of r;
  if not found then
    raise exception 'This report is no longer waiting for a decision.';
  end if;
  if exists (select 1 from public.closing_cases c where c.member_id = req.member_id) then
    raise exception 'A closing case already exists for this member.';
  end if;

  insert into public.closing_cases (
    member_id, yojna_id, closing_date, closing_group, claim_amount, nominee_name, remarks
  ) values (
    req.member_id, req.yojna_id, req.date_of_death, trim(p_closing_group),
    coalesce(p_claim_amount, req.claim_amount), req.nominee_name, req.remarks
  ) returning id into case_id;

  update public.closing_requests set
    status = 'approved', decided_by = (select auth.uid()), decided_at = now(),
    decision_note = '', closing_case_id = case_id
  where id = p_request_id;
  return case_id;
end $$;

create function public.reject_closing_request(p_request_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  if coalesce(trim(p_reason), '') = '' then
    raise exception 'Give a reason for rejecting.';
  end if;
  update public.closing_requests set
    status = 'rejected', decided_by = (select auth.uid()), decided_at = now(),
    decision_note = trim(p_reason)
  where id = p_request_id and status = 'pending';
  if not found then
    raise exception 'This report is no longer waiting for a decision.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on public.closing_groups, public.member_dues from anon, authenticated;
grant select on public.closing_groups, public.member_dues to authenticated;

revoke all on function public.check_payment_closing() from public, anon, authenticated;

revoke all on function
  public.agent_closing_groups(),
  public.agent_dues(uuid, text),
  public.agent_member_dues(uuid),
  public.agent_record_payment(jsonb),
  public.agent_payments(public.payment_status),
  public.agent_request_closing(jsonb),
  public.agent_closing_requests(),
  public.approve_closing_request(uuid, text, numeric),
  public.reject_closing_request(uuid, text)
from public, anon;

grant execute on function
  public.agent_closing_groups(),
  public.agent_dues(uuid, text),
  public.agent_member_dues(uuid),
  public.agent_record_payment(jsonb),
  public.agent_payments(public.payment_status),
  public.agent_request_closing(jsonb),
  public.agent_closing_requests(),
  public.approve_closing_request(uuid, text, numeric),
  public.reject_closing_request(uuid, text)
to authenticated;
