-- Release 2, Phase 16 (IMPLEMENTATION_PLAN §11): cash handovers and commission.
--
-- The tables (`cash_handovers`, `commission_payouts`, `payments.cash_handover_id`)
-- were created in 20260917000200_roles.sql; this migration fills them and adds
-- the functions agents and admins call. Agents still touch no table directly.
--
-- Decisions, so the numbers are not guesswork:
--
--   * "Cash in hand" counts **approved** (`paid`), not cancelled, `cash` receipts
--     the agent collected that are not linked to a handover. UPI, bank and
--     cheque never reach the agent's hand. Pending receipts are left out on
--     purpose: the office approves an agent's receipts first (Phase 12), so a
--     rejected receipt can never end up inside a declared handover.
--   * A handover is declared for whole receipts, not a free-typed amount, so
--     the office can check the total against the receipts it holds. The agent
--     may hand over everything (the default) or pick receipts.
--   * An admin who does not receive the money rejects the handover; its
--     receipts unlink and go back to cash in hand.
--   * Commission = the agent's `commission_percent` × approved, not cancelled
--     registration and contribution receipts dated in that IST calendar month.
--     Claim payouts are money going out and never count.
--   * A commission month is recalculated every time it is read. Marking it paid
--     stores the amount actually paid, so a later correction to an old receipt
--     shows up as a difference instead of silently rewriting history.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

-- `confirmed_by` / `confirmed_at` keep their literal meaning: they are set only
-- when the money was received. A rejection carries its reason instead.
alter table public.cash_handovers
  add column status        public.request_status not null default 'pending',
  add column decision_note text not null default '';

create index cash_handovers_pending_idx on public.cash_handovers (declared_at)
  where status = 'pending';

-- ---------------------------------------------------------------------------
-- Shared sums
-- ---------------------------------------------------------------------------

-- Cash the agent still holds. Internal: the app reads it through
-- `agent_summary()` and `agent_open_cash()`.
create function public.cash_in_hand(p_agent_id uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(p.amount), 0)
    from public.payments p
   where p.agent_id = p_agent_id
     and p.status = 'paid'
     and p.cancelled_at is null
     and p.mode = 'cash'
     and p.cash_handover_id is null;
$$;

-- What the agent collected in one calendar month, before the percentage.
create function public.commission_base(p_agent_id uuid, p_month date)
returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(sum(p.amount), 0)
    from public.payments p
   where p.agent_id = p_agent_id
     and p.status = 'paid'
     and p.cancelled_at is null
     and p.kind <> 'closingPayout'
     and p.date >= date_trunc('month', p_month)::date
     and p.date < (date_trunc('month', p_month) + interval '1 month')::date;
$$;

-- Rounded to the rupee, the way the office pays it.
create function public.commission_of(p_collected numeric, p_percent numeric)
returns numeric
language sql immutable set search_path = '' as $$
  select round(coalesce(p_collected, 0) * coalesce(p_percent, 0) / 100, 2);
$$;

-- ---------------------------------------------------------------------------
-- Agent: cash handovers
-- ---------------------------------------------------------------------------

-- The receipts that make up cash in hand, oldest first, for the declare form.
create function public.agent_open_cash()
returns table (
  id uuid, receipt_no text, member_name text, member_reg_no text,
  amount numeric, date date
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select p.id, p.receipt_no, m.name, coalesce(m.reg_no, ''), p.amount, p.date
    from public.payments p
    join public.members m on m.id = p.member_id
   where p.agent_id = a
     and p.status = 'paid'
     and p.cancelled_at is null
     and p.mode = 'cash'
     and p.cash_handover_id is null
   order by p.date, p.created_at;
end $$;

-- Declares cash handed to the office, waiting for an admin to confirm it.
-- `p_payment_ids` null means every open receipt.
-- Returns { "id": ..., "amount": ..., "count": ... }.
create function public.agent_declare_handover(
  p_payment_ids uuid[] default null,
  p_note        text default ''
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  a       uuid := public.require_agent();
  v_total numeric;
  v_count integer;
  v_id    uuid;
begin
  select coalesce(sum(p.amount), 0), count(*) into v_total, v_count
    from public.payments p
   where p.agent_id = a
     and p.status = 'paid'
     and p.cancelled_at is null
     and p.mode = 'cash'
     and p.cash_handover_id is null
     and (p_payment_ids is null or p.id = any (p_payment_ids));

  if v_count = 0 then
    raise exception 'There is no cash waiting to be handed over.';
  end if;
  if p_payment_ids is not null
     and v_count <> cardinality(array(select distinct unnest(p_payment_ids))) then
    raise exception 'One of those receipts is not yours, or is already in a handover.';
  end if;

  insert into public.cash_handovers (agent_id, amount, note)
  values (a, v_total, trim(coalesce(p_note, '')))
  returning id into v_id;

  update public.payments p set cash_handover_id = v_id
   where p.agent_id = a
     and p.status = 'paid'
     and p.cancelled_at is null
     and p.mode = 'cash'
     and p.cash_handover_id is null
     and (p_payment_ids is null or p.id = any (p_payment_ids));

  return jsonb_build_object('id', v_id, 'amount', v_total, 'count', v_count);
end $$;

-- The agent's own handovers, newest first.
create function public.agent_handovers()
returns table (
  id uuid, amount numeric, note text, status public.request_status,
  decision_note text, declared_at timestamptz, confirmed_at timestamptz,
  receipt_count bigint
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select h.id, h.amount, h.note, h.status, h.decision_note,
         h.declared_at, h.confirmed_at,
         (select count(*) from public.payments p where p.cash_handover_id = h.id)
    from public.cash_handovers h
   where h.agent_id = a
   order by h.declared_at desc;
end $$;

-- ---------------------------------------------------------------------------
-- Agent: commission
-- ---------------------------------------------------------------------------

-- The last `p_months` calendar months, newest first, including months with
-- nothing collected so the agent can see the run of them.
create function public.agent_commission(p_months integer default 6)
returns table (
  month date, collected numeric, percent numeric, amount numeric,
  paid_at timestamptz, paid_amount numeric, reference text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  a uuid := public.require_agent();
  v_percent numeric;
  v_months integer := least(greatest(coalesce(p_months, 6), 1), 24);
begin
  select ag.commission_percent into v_percent from public.agents ag where ag.id = a;

  return query
  select m.month,
         public.commission_base(a, m.month),
         v_percent,
         public.commission_of(public.commission_base(a, m.month), v_percent),
         c.paid_at,
         c.amount,
         coalesce(c.reference, '')
    from (
      select (date_trunc('month', public.today_ist())
              - (n || ' months')::interval)::date as month
        from generate_series(0, v_months - 1) as n
    ) m
    left join public.commission_payouts c
      on c.agent_id = a and c.month = m.month
   order by m.month desc;
end $$;

-- ---------------------------------------------------------------------------
-- Admin: handovers
-- ---------------------------------------------------------------------------

create function public.pending_handovers()
returns table (
  id uuid, agent_id uuid, agent_code text, agent_name text,
  amount numeric, note text, declared_at timestamptz, receipt_count bigint
)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.require_admin();
  return query
  select h.id, h.agent_id, ag.code, ag.name, h.amount, h.note, h.declared_at,
         (select count(*) from public.payments p where p.cash_handover_id = h.id)
    from public.cash_handovers h
    join public.agents ag on ag.id = h.agent_id
   where h.status = 'pending'
   order by h.declared_at;
end $$;

create function public.confirm_handover(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  update public.cash_handovers
     set status = 'approved', confirmed_by = (select auth.uid()),
         confirmed_at = now(), decision_note = ''
   where id = p_id and status = 'pending';
  if not found then
    raise exception 'This handover is no longer waiting for a decision.';
  end if;
end $$;

-- The receipts unlink, so the money goes back to the agent's cash in hand.
create function public.reject_handover(p_id uuid, p_reason text) returns void
language plpgsql security definer set search_path = '' as $$
declare v_reason text := trim(coalesce(p_reason, ''));
begin
  perform public.require_admin();
  if v_reason = '' then
    raise exception 'Give a reason.';
  end if;
  update public.cash_handovers
     set status = 'rejected', decision_note = v_reason
   where id = p_id and status = 'pending';
  if not found then
    raise exception 'This handover is no longer waiting for a decision.';
  end if;
  update public.payments set cash_handover_id = null where cash_handover_id = p_id;
end $$;

-- ---------------------------------------------------------------------------
-- Admin: commission report
-- ---------------------------------------------------------------------------

-- Every active agent for one month, so an agent who collected nothing is still
-- on the report. `p_month` is any date in the month.
create function public.commission_report(p_month date default null)
returns table (
  agent_id uuid, agent_code text, agent_name text, percent numeric,
  collected numeric, amount numeric, paid_at timestamptz,
  paid_amount numeric, reference text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare v_month date := date_trunc('month', coalesce(p_month, public.today_ist()))::date;
begin
  perform public.require_admin();
  return query
  select ag.id, ag.code, ag.name, ag.commission_percent,
         public.commission_base(ag.id, v_month),
         public.commission_of(public.commission_base(ag.id, v_month),
                              ag.commission_percent),
         c.paid_at, c.amount, coalesce(c.reference, '')
    from public.agents ag
    left join public.commission_payouts c
      on c.agent_id = ag.id and c.month = v_month
   where ag.is_active or c.id is not null
   order by ag.name;
end $$;

-- Owner only (§11.3). `p_amount` null means the calculated commission.
create function public.mark_commission_paid(
  p_agent_id  uuid,
  p_month     date,
  p_amount    numeric default null,
  p_reference text default ''
) returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_month   date := date_trunc('month', coalesce(p_month, public.today_ist()))::date;
  v_percent numeric;
  v_amount  numeric;
begin
  perform public.require_owner();
  select ag.commission_percent into v_percent
    from public.agents ag where ag.id = p_agent_id;
  if not found then
    raise exception 'Agent not found.';
  end if;
  if v_month > date_trunc('month', public.today_ist())::date then
    raise exception 'That month has not started yet.';
  end if;

  v_amount := coalesce(
    p_amount,
    public.commission_of(public.commission_base(p_agent_id, v_month), v_percent)
  );
  if v_amount < 0 then
    raise exception 'The amount cannot be negative.';
  end if;

  insert into public.commission_payouts
    (agent_id, month, amount, reference, paid_by, paid_at)
  values
    (p_agent_id, v_month, v_amount, trim(coalesce(p_reference, '')),
     (select auth.uid()), now())
  on conflict (agent_id, month) do update
    set amount = excluded.amount, reference = excluded.reference,
        paid_by = excluded.paid_by, paid_at = excluded.paid_at;
end $$;

-- ---------------------------------------------------------------------------
-- The agent home page (replaces the Phase 12 version)
-- ---------------------------------------------------------------------------

drop function public.agent_summary();

create function public.agent_summary()
returns table (
  active_members bigint, pending_members bigint,
  pending_payments bigint, pending_amount numeric, month_approved numeric,
  cash_in_hand numeric, handover_waiting numeric, month_commission numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare
  a uuid := public.require_agent();
  v_month date := date_trunc('month', public.today_ist())::date;
  v_percent numeric;
begin
  select ag.commission_percent into v_percent from public.agents ag where ag.id = a;

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
        and p.date >= v_month),
    public.cash_in_hand(a),
    (select coalesce(sum(h.amount), 0) from public.cash_handovers h
      where h.agent_id = a and h.status = 'pending'),
    public.commission_of(public.commission_base(a, v_month), v_percent);
end $$;

-- ---------------------------------------------------------------------------
-- Notifications (Phase 14)
-- ---------------------------------------------------------------------------

create function public.notify_handover_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_user uuid;
begin
  if new.status = old.status then return new; end if;
  v_user := public.agent_user_id(new.agent_id);
  if v_user is null then return new; end if;

  if new.status = 'approved' then
    perform public.notify(
      v_user, 'handover_confirmed', 'Cash handover confirmed',
      format('The office received %s.', to_char(new.amount, 'FM999G999G990D00')),
      '/agent/collections'
    );
  elsif new.status = 'rejected' then
    perform public.notify(
      v_user, 'handover_rejected', 'Cash handover not confirmed',
      coalesce(nullif(new.decision_note, ''), 'No reason given.'),
      '/agent/collections'
    );
  end if;
  return new;
end $$;

create trigger cash_handovers_notify_decision
  after update of status on public.cash_handovers
  for each row execute function public.notify_handover_decision();

-- Told when the month is first paid, and again if the amount is corrected.
-- `paid_at` alone is no guide: two payments in one transaction share `now()`.
create function public.notify_commission_paid() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_user uuid;
begin
  if new.paid_at is null then return new; end if;
  if tg_op = 'UPDATE'
     and old.paid_at is not null
     and new.amount is not distinct from old.amount then
    return new;
  end if;
  v_user := public.agent_user_id(new.agent_id);
  if v_user is null then return new; end if;

  perform public.notify(
    v_user, 'commission_paid', 'Commission paid',
    format('%s for %s.', to_char(new.amount, 'FM999G999G990D00'),
           to_char(new.month, 'Mon YYYY')),
    '/agent/collections'
  );
  return new;
end $$;

create trigger commission_payouts_notify_paid
  after insert or update on public.commission_payouts
  for each row execute function public.notify_commission_paid();

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- Helpers and trigger functions: nobody calls these directly.
revoke all on function
  public.cash_in_hand(uuid),
  public.commission_base(uuid, date),
  public.notify_handover_decision(),
  public.notify_commission_paid()
from public, anon, authenticated;

revoke all on function
  public.commission_of(numeric, numeric),
  public.agent_open_cash(),
  public.agent_declare_handover(uuid[], text),
  public.agent_handovers(),
  public.agent_commission(integer),
  public.agent_summary(),
  public.pending_handovers(),
  public.confirm_handover(uuid),
  public.reject_handover(uuid, text),
  public.commission_report(date),
  public.mark_commission_paid(uuid, date, numeric, text)
from public, anon;

grant execute on function
  public.agent_open_cash(),
  public.agent_declare_handover(uuid[], text),
  public.agent_handovers(),
  public.agent_commission(integer),
  public.agent_summary(),
  public.pending_handovers(),
  public.confirm_handover(uuid),
  public.reject_handover(uuid, text),
  public.commission_report(date),
  public.mark_commission_paid(uuid, date, numeric, text)
to authenticated;
