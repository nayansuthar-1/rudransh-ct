-- A closing is any claim a Yojna pays out, not only a death: in Shadi Sahyog
-- Yojna it is a member's wedding. The client's rules (25 Sep 2026):
--
--   1. Every closing is collected on its own. Each active member of the Yojna
--      owes one contribution for it, whatever closing group it is in; two
--      closings in Group-14 are two contributions.
--   2. A member owes for every closing created after they were added to the
--      app, whatever join date was typed in. Someone added later does not owe
--      for closings created before them.
--   3. The member whose closing it is stays Active and keeps paying for other
--      members' closings. Only their own closing is left out.
--
-- Until now a closing marked its member Closed, and dues were counted once per
-- closing group for members who joined before the group's first closing date.

-- ---------------------------------------------------------------------------
-- The member stays active
-- ---------------------------------------------------------------------------

-- Members this trigger closed go back to Active. A member closed by hand
-- (no closing case) keeps their status.
update public.members m
   set status = 'active'
 where m.status = 'closed'
   and exists (select 1 from public.closing_cases c where c.member_id = m.id);

-- Still copies the closing's date and group onto the member, for the member
-- list and certificate; no longer touches the status.
create or replace function public.sync_member_on_closing() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op in ('INSERT', 'UPDATE') then
    update public.members
       set closing_date = new.closing_date, closing_group = new.closing_group
     where id = new.member_id;
  elsif tg_op = 'DELETE' and pg_trigger_depth() = 1 then
    -- Depth > 1 means the member itself is being deleted (cascade); skip.
    update public.members
       set closing_date = null, closing_group = null
     where id = old.member_id;
  end if;
  return null;
end $$;

-- ---------------------------------------------------------------------------
-- Dues: one row per member per closing case
-- ---------------------------------------------------------------------------

-- Same columns as before, so everything reading the view keeps working:
-- [closing_case_id] is now the case itself and [case_count] is always 1.
-- [beneficiary_name] is the member whose closing it is.
create or replace view public.member_dues with (security_invoker = true) as
select c.yojna_id,
       c.closing_group,
       c.closing_date,
       c.id as closing_case_id,
       1::bigint as case_count,
       m.id as member_id,
       m.agent_id,
       y.contribution_amount as amount,
       coalesce(sum(p.amount) filter (where p.status = 'paid'), 0) as paid,
       coalesce(sum(p.amount) filter (where p.status = 'pending'), 0) as pending,
       greatest(y.contribution_amount
                - coalesce(sum(p.amount) filter (where p.status = 'paid'), 0), 0) as due,
       b.name as beneficiary_name
  from public.closing_cases c
  join public.yojnas y on y.id = c.yojna_id
  join public.members b on b.id = c.member_id
  join public.members m
    on m.yojna_id = c.yojna_id
   and m.status = 'active'
   and m.id <> c.member_id
   and m.created_at <= c.created_at
  left join public.payments p
    on p.member_id = m.id
   and p.kind = 'contribution'
   and p.cancelled_at is null
   and p.closing_case_id = c.id
 group by c.id, c.yojna_id, c.closing_group, c.closing_date, b.name,
          m.id, m.agent_id, y.contribution_amount;

-- ---------------------------------------------------------------------------
-- Agent: a contribution is checked against its own closing
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
     where md.member_id = mem.id and md.closing_case_id = cc;
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

-- ---------------------------------------------------------------------------
-- Agent: dues per closing
-- ---------------------------------------------------------------------------

-- One row per closing the agent's members owe for, newest first. Adds the
-- beneficiary's name, so the return type changes and the function is made
-- again. Page with `.range()`.
drop function public.agent_closing_groups();

create function public.agent_closing_groups()
returns table (
  yojna_id uuid, yojna_name text, closing_group text, closing_date date,
  closing_case_id uuid, case_count bigint, member_count bigint, paid_count bigint,
  pending_count bigint, due_count bigint, to_collect numeric, beneficiary_name text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select d.yojna_id, y.name, d.closing_group, d.closing_date,
         d.closing_case_id, 1::bigint, count(*),
         count(*) filter (where d.due = 0),
         count(*) filter (where d.due > 0 and d.pending > 0),
         count(*) filter (where d.due > 0 and d.pending = 0),
         coalesce(sum(greatest(d.due - d.pending, 0)), 0),
         d.beneficiary_name
    from public.member_dues d
    join public.yojnas y on y.id = d.yojna_id
   where d.agent_id = a
   group by d.yojna_id, y.name, d.closing_group, d.closing_date, d.closing_case_id,
            d.beneficiary_name
   order by d.closing_date desc, d.closing_group, d.beneficiary_name;
end $$;

-- The agent's members for one closing: still due first, then waiting for
-- approval, then paid. Replaces agent_dues, which asked by closing group.
create function public.agent_closing_dues(p_closing_case_id uuid)
returns table (
  member_id uuid, reg_no text, name text, primary_phone text, village text,
  yojna_id uuid, closing_case_id uuid, closing_group text, closing_date date,
  amount numeric, paid numeric, pending numeric, due numeric, beneficiary_name text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select m.id, m.reg_no, m.name, m.primary_phone, m.village,
         d.yojna_id, d.closing_case_id, d.closing_group, d.closing_date,
         d.amount, d.paid, d.pending, d.due, d.beneficiary_name
    from public.member_dues d
    join public.members m on m.id = d.member_id
   where d.agent_id = a
     and d.closing_case_id = p_closing_case_id
   order by case when d.due = 0 then 2 when d.pending > 0 then 1 else 0 end, m.name;
end $$;

revoke all on function public.agent_closing_groups(), public.agent_closing_dues(uuid)
from public, anon;
grant execute on function public.agent_closing_groups(), public.agent_closing_dues(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Overdue reminders: one per agent per closing
-- ---------------------------------------------------------------------------

create or replace function public.notify_overdue_dues(p_days integer default 30)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_sent integer := 0;
  r      record;
  v_user uuid;
  v_what text;
begin
  for r in
    select d.agent_id, d.closing_case_id, d.closing_group, d.beneficiary_name,
           y.name as yojna_name, count(*) as still_due
      from public.member_dues d
      join public.yojnas y on y.id = d.yojna_id
     where d.due > 0
       and d.agent_id is not null
       and d.closing_date <= current_date - p_days
     group by d.agent_id, d.closing_case_id, d.closing_group, d.beneficiary_name, y.name
  loop
    v_user := public.agent_user_id(r.agent_id);
    if v_user is null then continue; end if;
    v_what := format('%s (%s)', coalesce(nullif(r.closing_group, ''), 'the closing'),
                     r.beneficiary_name);
    -- Already told today? Leave it.
    if exists (
      select 1 from public.notifications n
       where n.user_id = v_user and n.type = 'dues_overdue'
         and n.created_at >= current_date
         and n.link = '/agent/dues'
         and n.body like '%' || v_what || '%'
    ) then
      continue;
    end if;
    perform public.notify(
      v_user, 'dues_overdue', 'Dues are overdue',
      format('%s member(s) have not paid for %s in %s, open more than %s days.',
             r.still_due, v_what, r.yojna_name, p_days),
      '/agent/dues'
    );
    v_sent := v_sent + 1;
  end loop;
  return v_sent;
end $$;

-- ---------------------------------------------------------------------------
-- Wording: a closing report, not a death report
-- ---------------------------------------------------------------------------

create or replace function public.agent_request_closing(p_request jsonb) returns uuid
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
    raise exception 'Only an active member can be reported for a closing.';
  end if;
  if d is null then
    raise exception 'Enter the event date.';
  end if;
  if d > public.today_ist() then
    raise exception 'The event date cannot be in the future.';
  end if;
  if d < mem.join_date then
    raise exception 'The event date is before the member joined.';
  end if;
  if url !~ '^https://res\.cloudinary\.com/' then
    raise exception 'Upload the proof document.';
  end if;
  if exists (
    select 1 from public.closing_requests r where r.member_id = mem.id and r.status = 'pending'
  ) then
    raise exception 'A report for this member is already waiting for the office.';
  end if;
  if exists (select 1 from public.closing_cases c where c.member_id = mem.id) then
    raise exception 'This member already has a closing.';
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

create or replace function public.notify_closing_request_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid;
  v_name text;
begin
  if new.status = old.status or new.agent_id is null then
    return new;
  end if;
  v_user := public.agent_user_id(new.agent_id);
  if v_user is null then return new; end if;

  select m.name into v_name from public.members m where m.id = new.member_id;
  v_name := coalesce(v_name, 'a member');

  if new.status = 'approved' then
    perform public.notify(
      v_user, 'closing_approved', 'Closing report approved',
      format('The report for %s is approved and a closing case is open.', v_name),
      '/agent/dues'
    );
  elsif new.status = 'rejected' then
    perform public.notify(
      v_user, 'closing_rejected', 'Closing report rejected',
      format('The report for %s was rejected. %s', v_name,
             coalesce(nullif(trim(new.decision_note), ''), 'No reason given.')),
      '/agent/dues'
    );
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Dashboard: "Closing Members" counts members who have a closing
-- ---------------------------------------------------------------------------

-- Nobody is Closed by a closing any more, so the tile counts closing cases'
-- members instead of the Closed status.
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
           count(*) filter (where status = 'inactive') as inactive
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
    select coalesce(sum(greatest(claim_amount - collected_amount, 0))
                    filter (where pay_status <> 'paid'), 0) as pending,
           count(*) as members
      from public.closing_cases
     where p_yojna_id is null or yojna_id = p_yojna_id
  )
  select m.total, m.active, m.inactive, c.members, a.total, a.active,
         p.month_total, p.prev_total, c.pending
    from m, a, p, c;
$$;
