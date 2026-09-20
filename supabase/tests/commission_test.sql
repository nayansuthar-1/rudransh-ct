-- Phase 16 (IMPLEMENTATION_PLAN §11): cash handovers and commission.
-- Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/commission_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   c001 owner   c002 staff   c003 agent A (10%)   c004 agent B (5%)
--
-- Agent A's receipts, all approved unless said otherwise. This month:
--   P1  cash   100                                → cash in hand, commission
--   P2  cash   200                                → cash in hand, commission
--   P3  upi    300                                → commission only, never in hand
--   P4  cash   400  pending                       → neither: not approved yet
--   P5  cash   500  cancelled                     → neither
--   P6  cash   600  registration                  → cash in hand, commission
--   P7  closingPayout 5000                        → cash in hand, never commission
-- Last month:
--   P8  cash  1000                                → cash in hand, last month's commission
--
-- So cash in hand = 100 + 200 + 600 + 5000 + 1000 = 6900
--    this month's commission base = 100 + 200 + 300 + 600 = 1200, at 10% = 120
--    last month's base = 1000, at 10% = 100
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000c0' || lpad(g::text, 2, '0'))::uuid,
       'comm' || g || '@test.local'
  from generate_series(1, 4) g;

insert into public.yojnas (id, name, code, contribution_amount, claim_amount, registration_fee) values
  ('00000000-0000-0000-0000-0000000c0001', 'Comm One', 'CMQA', 100, 50000, 50);

insert into public.agents (id, code, name, commission_percent) values
  ('00000000-0000-0000-0000-0000000c0011', '', 'Comm Agent A', 10),
  ('00000000-0000-0000-0000-0000000c0012', '', 'Comm Agent B', 5);

insert into public.members (id, yojna_id, name, primary_phone, agent_id, join_date, status) values
  ('00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001', 'Comm M1',
   '9600000001', '00000000-0000-0000-0000-0000000c0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000c0022', '00000000-0000-0000-0000-0000000c0001', 'Comm M2',
   '9600000002', '00000000-0000-0000-0000-0000000c0012', current_date - 400, 'active');

-- `date_trunc('month', now())` is the first of this month, which is always a
-- valid payment date; last month's receipt is dated the same day a month back.
insert into public.payments
  (receipt_no, member_id, yojna_id, agent_id, amount, date, mode, status, kind, cancelled_at, source)
values
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 100, date_trunc('month', public.today_ist())::date,
   'cash', 'paid', 'contribution', null, 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 200, date_trunc('month', public.today_ist())::date,
   'cash', 'paid', 'contribution', null, 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 300, date_trunc('month', public.today_ist())::date,
   'upi', 'paid', 'contribution', null, 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 400, date_trunc('month', public.today_ist())::date,
   'cash', 'pending', 'contribution', null, 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 500, date_trunc('month', public.today_ist())::date,
   'cash', 'paid', 'contribution', now(), 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 600, date_trunc('month', public.today_ist())::date,
   'cash', 'paid', 'registration', null, 'agent'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 5000, date_trunc('month', public.today_ist())::date,
   'cash', 'paid', 'closingPayout', null, 'admin'),
  ('', '00000000-0000-0000-0000-0000000c0021', '00000000-0000-0000-0000-0000000c0001',
   '00000000-0000-0000-0000-0000000c0011', 1000,
   (date_trunc('month', public.today_ist()) - interval '1 month')::date,
   'cash', 'paid', 'contribution', null, 'agent');

insert into public.profiles (user_id, role, agent_id) values
  ('00000000-0000-0000-0000-00000000c001', 'owner', null),
  ('00000000-0000-0000-0000-00000000c002', 'staff', null),
  ('00000000-0000-0000-0000-00000000c003', 'agent', '00000000-0000-0000-0000-0000000c0011'),
  ('00000000-0000-0000-0000-00000000c004', 'agent', '00000000-0000-0000-0000-0000000c0012');

-- Ids shared between the role blocks below.
create temporary table ct (key text primary key, id uuid) on commit drop;
grant all on ct to authenticated;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Agent A: cash in hand and the declare form
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c003', true);

do $$
declare s record; r jsonb; n integer;
begin
  select * into s from public.agent_summary();
  assert s.cash_in_hand = 6900, format('cash in hand is %s, expected 6900', s.cash_in_hand);
  assert s.month_commission = 120, format('commission is %s, expected 120', s.month_commission);
  assert s.handover_waiting = 0, 'nothing declared yet';

  -- The open-cash list is the same money, receipt by receipt.
  select count(*), coalesce(sum(amount), 0) into n, s.cash_in_hand
    from public.agent_open_cash();
  assert n = 5, format('%s open cash receipts, expected 5', n);
  assert s.cash_in_hand = 6900, 'open cash adds up to cash in hand';

  -- Six months back, newest first, this month at the top.
  assert (select count(*) from public.agent_commission(6)) = 6, 'six months listed';
  assert (select amount from public.agent_commission(6)
           order by month desc limit 1) = 120, 'this month at 10%';
  assert (select amount from public.agent_commission(6)
           order by month desc offset 1 limit 1) = 100, 'last month at 10%';
  assert (select paid_at from public.agent_commission(6)
           order by month desc limit 1) is null, 'not paid yet';

  -- Declaring everything: one handover for the whole 6900.
  r := public.agent_declare_handover();
  assert (r ->> 'amount')::numeric = 6900, format('declared %s', r ->> 'amount');
  assert (r ->> 'count')::integer = 5, format('declared %s receipts', r ->> 'count');
  insert into ct values ('handover', (r ->> 'id')::uuid);

  -- The money has left the agent's hand and is waiting for the office.
  select * into s from public.agent_summary();
  assert s.cash_in_hand = 0, format('cash in hand is %s after declaring', s.cash_in_hand);
  assert s.handover_waiting = 6900, format('waiting is %s', s.handover_waiting);
  assert (select count(*) from public.agent_open_cash()) = 0, 'nothing left to declare';

  -- Nothing open, so there is nothing to declare twice.
  begin
    perform public.agent_declare_handover();
    raise exception 'declared an empty handover';
  exception when raise_exception then
    if sqlerrm not like 'There is no cash waiting%' then raise; end if;
  end;

  assert (select receipt_count from public.agent_handovers()) = 5, 'five receipts in it';
  assert (select status from public.agent_handovers()) = 'pending', 'waiting for the office';
  raise notice 'agent cash checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Agent B: sees only their own
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c004', true);

do $$
declare s record;
begin
  select * into s from public.agent_summary();
  assert s.cash_in_hand = 0, 'agent B collected nothing';
  assert s.month_commission = 0, 'no commission for agent B';
  assert (select count(*) from public.agent_handovers()) = 0, 'agent A''s handover is not agent B''s';
  assert (select count(*) from public.agent_open_cash()) = 0, 'no open cash';

  -- Another agent's receipts cannot be pulled into a handover.
  begin
    perform public.agent_declare_handover(
      array(select id from public.payments where agent_id =
            '00000000-0000-0000-0000-0000000c0011'::uuid));
    raise exception 'agent B declared agent A''s receipts';
  exception when raise_exception then
    if sqlerrm not like 'There is no cash waiting%' then raise; end if;
  end;

  -- Admin-only doors are shut.
  begin
    perform public.pending_handovers();
    raise exception 'agent called pending_handovers';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.commission_report(null);
    raise exception 'agent called commission_report';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.mark_commission_paid(
      '00000000-0000-0000-0000-0000000c0012', public.today_ist(), 10, 'x');
    raise exception 'agent marked commission paid';
  exception when insufficient_privilege then null;
  end;
  raise notice 'agent B checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Staff admin: confirms handovers, but does not pay commission
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c002', true);

do $$
declare h record; v_id uuid;
begin
  select id into v_id from ct where key = 'handover';

  select * into h from public.pending_handovers();
  assert h.id = v_id, 'the declared handover is in the queue';
  assert h.amount = 6900, format('queue shows %s', h.amount);
  assert h.receipt_count = 5, 'five receipts';
  assert h.agent_name = 'Comm Agent A', 'named agent';

  -- A rejection needs a reason.
  begin
    perform public.reject_handover(v_id, '   ');
    raise exception 'rejected without a reason';
  exception when raise_exception then
    if sqlerrm not like 'Give a reason%' then raise; end if;
  end;

  -- Commission is the owner's to pay, not staff's.
  begin
    perform public.mark_commission_paid(
      '00000000-0000-0000-0000-0000000c0011', public.today_ist(), 120, 'x');
    raise exception 'staff marked commission paid';
  exception when insufficient_privilege then null;
  end;

  -- Rejecting sends the money back to the agent's hand.
  perform public.reject_handover(v_id, 'Short by 100');
  assert (select count(*) from public.pending_handovers()) = 0, 'queue is empty again';
  -- `cash_in_hand()` is an internal helper an admin may not call, so count the
  -- unlinked cash receipts the same way it does.
  assert (select coalesce(sum(p.amount), 0) from public.payments p
           where p.agent_id = '00000000-0000-0000-0000-0000000c0011'
             and p.status = 'paid' and p.cancelled_at is null
             and p.mode = 'cash' and p.cash_handover_id is null) = 6900,
    'rejected money is back in hand';

  -- And it cannot be decided twice.
  begin
    perform public.confirm_handover(v_id);
    raise exception 'confirmed a rejected handover';
  exception when raise_exception then
    if sqlerrm not like 'This handover is no longer%' then raise; end if;
  end;
  raise notice 'staff checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Agent A again: declares part of it, and hears the outcome
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c003', true);

do $$
declare r jsonb; ids uuid[];
begin
  assert (select decision_note from public.agent_handovers()) = 'Short by 100',
    'agent sees why it was refused';
  assert (select status from public.agent_handovers()) = 'rejected', 'and that it was refused';

  -- Picking two of the five receipts.
  select array_agg(id) into ids from (
    select id from public.agent_open_cash() order by amount limit 2
  ) pick;
  r := public.agent_declare_handover(ids, 'Handed at the office');
  assert (r ->> 'amount')::numeric = 300, format('partial handover is %s, expected 300', r ->> 'amount');
  insert into ct values ('partial', (r ->> 'id')::uuid);

  -- The rest is still the agent's to hand over.
  assert (select coalesce(sum(amount), 0) from public.agent_open_cash()) = 6600,
    'the rest stays in hand';

  -- A receipt already inside a handover cannot go into a second one.
  begin
    perform public.agent_declare_handover(ids);
    raise exception 'declared the same receipts twice';
  exception when raise_exception then
    if sqlerrm not like 'There is no cash waiting%' then raise; end if;
  end;
  raise notice 'partial handover checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Owner: confirms the handover and pays commission
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c001', true);

do $$
declare v_id uuid; r record; v_month date := date_trunc('month', public.today_ist())::date;
begin
  select id into v_id from ct where key = 'partial';
  perform public.confirm_handover(v_id);
  assert (select count(*) from public.pending_handovers()) = 0, 'nothing left in the queue';
  -- Confirmed money does not come back: the receipts stay linked.
  assert (select coalesce(sum(p.amount), 0) from public.payments p
           where p.agent_id = '00000000-0000-0000-0000-0000000c0011'
             and p.status = 'paid' and p.cancelled_at is null
             and p.mode = 'cash' and p.cash_handover_id is null) = 6600,
    'confirmed money stays out of the agent''s hand';

  -- The report lists every active agent, including one who collected nothing.
  assert (select count(*) from public.commission_report(v_month)
           where agent_name like 'Comm Agent%') = 2, 'both agents on the report';
  select * into r from public.commission_report(v_month) where agent_name = 'Comm Agent A';
  assert r.collected = 1200, format('collected %s, expected 1200', r.collected);
  assert r.amount = 120, format('commission %s, expected 120', r.amount);
  assert r.paid_at is null, 'not paid yet';

  -- Paying it with no amount uses the calculated one.
  perform public.mark_commission_paid('00000000-0000-0000-0000-0000000c0011', v_month, null, 'UPI 9931');
  select * into r from public.commission_report(v_month) where agent_name = 'Comm Agent A';
  assert r.paid_amount = 120, format('paid %s, expected 120', r.paid_amount);
  assert r.reference = 'UPI 9931', 'reference kept';
  assert r.paid_at is not null, 'stamped as paid';

  -- Paying the same month again corrects it rather than failing.
  perform public.mark_commission_paid('00000000-0000-0000-0000-0000000c0011', v_month, 150, 'Cash');
  select * into r from public.commission_report(v_month) where agent_name = 'Comm Agent A';
  assert r.paid_amount = 150, format('corrected to %s, expected 150', r.paid_amount);
  assert r.amount = 120, 'the calculated commission is unchanged';

  -- A month that has not started yet cannot be paid.
  begin
    perform public.mark_commission_paid(
      '00000000-0000-0000-0000-0000000c0011', (v_month + interval '1 month')::date, 10, 'x');
    raise exception 'paid a future month';
  exception when raise_exception then
    if sqlerrm not like 'That month has not started%' then raise; end if;
  end;
  raise notice 'owner checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- The agent hears about both decisions
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c003', true);

do $$
begin
  assert (select count(*) from public.my_notifications(50)
           where type = 'handover_rejected') = 1, 'told the handover was refused';
  assert (select count(*) from public.my_notifications(50)
           where type = 'handover_confirmed') = 1, 'told the handover was received';
  -- Two payments, one insert and one correction, are two pieces of news.
  assert (select count(*) from public.my_notifications(50)
           where type = 'commission_paid') = 2, 'told the commission was paid';
  assert (select body from public.my_notifications(50)
           where type = 'handover_rejected') = 'Short by 100', 'with the reason';

  -- The agent's own view agrees with the owner's report.
  assert (select paid_amount from public.agent_commission(6)
           order by month desc limit 1) = 150, 'agent sees what was paid';
  raise notice 'notification checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Anon: nothing
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

do $$
begin
  begin
    perform public.agent_open_cash();
    raise exception 'anon called agent_open_cash';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.agent_declare_handover();
    raise exception 'anon declared a handover';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.commission_report(null);
    raise exception 'anon called commission_report';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.cash_in_hand('00000000-0000-0000-0000-0000000c0011');
    raise exception 'anon called cash_in_hand';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.cash_handovers;
    raise exception 'anon read cash_handovers';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.commission_payouts;
    raise exception 'anon read commission_payouts';
  exception when insufficient_privilege then null;
  end;
  raise notice 'anon checks passed';
end $$;

reset role;
rollback;
