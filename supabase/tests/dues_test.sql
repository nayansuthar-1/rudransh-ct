-- Phase 13 (IMPLEMENTATION_PLAN §11): dues per closing group, contributions
-- linked to a closing, agents reporting a death. Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/dues_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   f001 owner   f002 agent A (Y1)   f003 agent B (Y1)
--
-- Closing group G-1 in Y1: deaths of D1 (200 days ago) and D2 (190 days ago).
-- Who owes for G-1, counted by hand:
--   M1  agent A, joined 400 days ago, paid 100 (linked to D2's case)   → paid
--   M2  agent A, joined 400 days ago, agent collects 100 below         → pending
--   M3  agent B, joined 400 days ago, nothing                          → due
--   M4  agent A, joined 100 days ago (after the closing)               → not listed
--   M5  agent A, joined 400 days ago, inactive                         → not listed
--   D1, D2 closed                                                      → not listed
--   X1  Y2 member                                                      → not listed
-- So G-1 lists 3 members: 1 paid, 1 pending, 1 due; 200 still unpaid.
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000f0' || lpad(g::text, 2, '0'))::uuid, 'dues' || g || '@test.local'
  from generate_series(1, 3) g;

insert into public.yojnas (id, name, code, contribution_amount, claim_amount, registration_fee) values
  ('00000000-0000-0000-0000-0000000f0001', 'Dues One', 'DUQA', 100, 50000, 50),
  ('00000000-0000-0000-0000-0000000f0002', 'Dues Two', 'DUQB', 200, 90000, 50);

insert into public.agents (id, code, name, yojna_ids) values
  ('00000000-0000-0000-0000-0000000f0011', '', 'Dues Agent A', array['00000000-0000-0000-0000-0000000f0001'::uuid]),
  ('00000000-0000-0000-0000-0000000f0012', '', 'Dues Agent B', array['00000000-0000-0000-0000-0000000f0001'::uuid]);

insert into public.members (id, yojna_id, name, primary_phone, agent_id, join_date, status) values
  ('00000000-0000-0000-0000-0000000f0021', '00000000-0000-0000-0000-0000000f0001', 'Dues M1', '9700000001',
   '00000000-0000-0000-0000-0000000f0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000f0022', '00000000-0000-0000-0000-0000000f0001', 'Dues M2', '9700000002',
   '00000000-0000-0000-0000-0000000f0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000f0023', '00000000-0000-0000-0000-0000000f0001', 'Dues M3', '9700000003',
   '00000000-0000-0000-0000-0000000f0012', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000f0024', '00000000-0000-0000-0000-0000000f0001', 'Dues M4', '9700000004',
   '00000000-0000-0000-0000-0000000f0011', current_date - 100, 'active'),
  ('00000000-0000-0000-0000-0000000f0025', '00000000-0000-0000-0000-0000000f0001', 'Dues M5', '9700000005',
   '00000000-0000-0000-0000-0000000f0011', current_date - 400, 'inactive'),
  ('00000000-0000-0000-0000-0000000f0026', '00000000-0000-0000-0000-0000000f0001', 'Dues D1', '9700000006',
   '00000000-0000-0000-0000-0000000f0011', current_date - 900, 'active'),
  ('00000000-0000-0000-0000-0000000f0027', '00000000-0000-0000-0000-0000000f0001', 'Dues D2', '9700000007',
   '00000000-0000-0000-0000-0000000f0012', current_date - 900, 'active'),
  ('00000000-0000-0000-0000-0000000f0028', '00000000-0000-0000-0000-0000000f0002', 'Dues X1', '9700000008',
   '00000000-0000-0000-0000-0000000f0011', current_date - 400, 'active');

insert into public.closing_cases (id, member_id, yojna_id, closing_date, closing_group, claim_amount) values
  ('00000000-0000-0000-0000-0000000f0031', '00000000-0000-0000-0000-0000000f0026',
   '00000000-0000-0000-0000-0000000f0001', current_date - 200, 'G-1', 50000),
  ('00000000-0000-0000-0000-0000000f0032', '00000000-0000-0000-0000-0000000f0027',
   '00000000-0000-0000-0000-0000000f0001', current_date - 190, 'G-1', 50000);

-- Office receipt for M1, linked to the group's second case.
insert into public.payments (receipt_no, member_id, yojna_id, amount, status, kind, closing_case_id) values
  ('', '00000000-0000-0000-0000-0000000f0021', '00000000-0000-0000-0000-0000000f0001', 100, 'paid',
   'contribution', '00000000-0000-0000-0000-0000000f0032');

insert into public.profiles (user_id, role, agent_id) values
  ('00000000-0000-0000-0000-00000000f001', 'owner', null),
  ('00000000-0000-0000-0000-00000000f002', 'agent', '00000000-0000-0000-0000-0000000f0011'),
  ('00000000-0000-0000-0000-00000000f003', 'agent', '00000000-0000-0000-0000-0000000f0012');

do $$
begin
  -- A closing link must be a contribution in the same Yojna, not the member's own case.
  begin
    insert into public.payments (receipt_no, member_id, yojna_id, amount, kind, closing_case_id) values
      ('', '00000000-0000-0000-0000-0000000f0021', '00000000-0000-0000-0000-0000000f0001', 50,
       'registration', '00000000-0000-0000-0000-0000000f0031');
    raise exception 'registration fee linked to a closing';
  exception when raise_exception then
    if sqlerrm not like 'Only a contribution%' then raise; end if;
  end;
  begin
    insert into public.payments (receipt_no, member_id, yojna_id, amount, kind, closing_case_id) values
      ('', '00000000-0000-0000-0000-0000000f0028', '00000000-0000-0000-0000-0000000f0002', 200,
       'contribution', '00000000-0000-0000-0000-0000000f0031');
    raise exception 'contribution linked to another Yojna''s closing';
  exception when raise_exception then
    if sqlerrm not like 'That closing is not%' then raise; end if;
  end;
  raise notice 'closing link checks passed';
end $$;

-- Shared ids between the blocks below.
create temporary table dt (key text primary key, id uuid) on commit drop;
grant all on dt to authenticated;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Agent A: dues for their own members only
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000f002', true);

do $$
declare
  y1 constant uuid := '00000000-0000-0000-0000-0000000f0001';
  m1 constant uuid := '00000000-0000-0000-0000-0000000f0021';
  m2 constant uuid := '00000000-0000-0000-0000-0000000f0022';
  m3 constant uuid := '00000000-0000-0000-0000-0000000f0023';
  m4 constant uuid := '00000000-0000-0000-0000-0000000f0024';
  c1 constant uuid := '00000000-0000-0000-0000-0000000f0031';
  g record; r jsonb; req uuid;
begin
  -- Views follow table access: nothing for an agent.
  assert (select count(*) from public.member_dues) = 0, 'agent reads member_dues directly';

  -- Before collecting: M1 paid, M2 due.
  select * into g from public.agent_closing_groups();
  assert g.closing_group = 'G-1' and g.case_count = 2, 'group G-1 with two cases';
  assert g.closing_case_id = c1, 'group links to its first case';
  assert g.member_count = 2 and g.paid_count = 1 and g.due_count = 1 and g.pending_count = 0,
    'A1 before collecting: ' || row_to_json(g)::text;
  assert g.to_collect = 100, 'to collect before: ' || g.to_collect;

  assert (select count(*) from public.agent_dues(y1, 'G-1')) = 2, 'A sees two members in G-1';
  assert not exists (select 1 from public.agent_dues(y1, 'G-1') where member_id = m3), 'A does not see B''s member';
  assert (select member_id from public.agent_dues(y1, 'G-1') limit 1) = m2, 'still due listed first';
  assert (select due from public.agent_member_dues(m1)) = 0, 'M1 paid for G-1';
  assert (select count(*) from public.agent_member_dues(m4)) = 0, 'M4 joined after the closing';

  -- Collect from M2 for the group.
  r := public.agent_record_payment(jsonb_build_object(
    'member_id', m2, 'amount', 100, 'closing_case_id', c1));
  insert into dt values ('p_m2', (r ->> 'id')::uuid);
  assert (select closing_group from public.agent_payments() where id = (r ->> 'id')::uuid) = 'G-1',
    'receipt shows its closing group';
  assert (select member_phone from public.agent_payments() where id = (r ->> 'id')::uuid) = '9700000002',
    'receipt has the member phone';

  select * into g from public.agent_closing_groups();
  assert g.paid_count = 1 and g.pending_count = 1 and g.due_count = 0 and g.to_collect = 0,
    'A1 after collecting: ' || row_to_json(g)::text;

  -- No second collection, no dues for members who do not owe.
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m2, 'amount', 100, 'closing_case_id', c1));
    raise exception 'collected twice for the same closing';
  exception when raise_exception then
    if sqlerrm not like '%already collected%' then raise; end if;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m1, 'amount', 100,
      'closing_case_id', '00000000-0000-0000-0000-0000000f0032'));
    raise exception 'collected from a member who already paid';
  exception when raise_exception then
    if sqlerrm not like '%already collected%' then raise; end if;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m4, 'amount', 100, 'closing_case_id', c1));
    raise exception 'collected from a member who joined after the closing';
  exception when raise_exception then
    if sqlerrm <> 'This member does not owe for that closing.' then raise; end if;
  end;
  begin
    perform public.agent_member_dues(m3);
    raise exception 'agent read another agent''s member dues';
  exception when raise_exception then
    if sqlerrm <> 'Member not found.' then raise; end if;
  end;

  -- Reporting deaths.
  begin
    perform public.agent_request_closing(jsonb_build_object('member_id', m3, 'date_of_death', current_date - 1,
      'certificate_url', 'https://res.cloudinary.com/demo/image/upload/c.jpg'));
    raise exception 'agent reported another agent''s member';
  exception when raise_exception then
    if sqlerrm <> 'Member not found.' then raise; end if;
  end;
  begin
    perform public.agent_request_closing(jsonb_build_object('member_id', m1, 'date_of_death', current_date - 1,
      'certificate_url', 'https://example.com/c.jpg'));
    raise exception 'report without a Cloudinary certificate accepted';
  exception when raise_exception then
    if sqlerrm <> 'Upload the death certificate.' then raise; end if;
  end;
  begin
    perform public.agent_request_closing(jsonb_build_object('member_id', m1, 'date_of_death', current_date + 1,
      'certificate_url', 'https://res.cloudinary.com/demo/image/upload/c.jpg'));
    raise exception 'future date of death accepted';
  exception when raise_exception then null;
  end;

  req := public.agent_request_closing(jsonb_build_object(
    'member_id', m1, 'date_of_death', current_date - 3, 'nominee_name', 'Nominee One',
    'nominee_relation', 'Son', 'certificate_url', 'https://res.cloudinary.com/demo/image/upload/m1.jpg'));
  insert into dt values ('req_m1', req);
  begin
    perform public.agent_request_closing(jsonb_build_object('member_id', m1, 'date_of_death', current_date - 3,
      'certificate_url', 'https://res.cloudinary.com/demo/image/upload/m1.jpg'));
    raise exception 'second open report accepted';
  exception when raise_exception then
    if sqlerrm not like 'A report for this member%' then raise; end if;
  end;
  req := public.agent_request_closing(jsonb_build_object(
    'member_id', m2, 'date_of_death', current_date - 2,
    'certificate_url', 'https://res.cloudinary.com/demo/image/upload/m2.pdf'));
  insert into dt values ('req_m2', req);

  assert (select count(*) from public.agent_closing_requests()) = 2, 'A sees own reports';
  assert (select status from public.agent_closing_requests() where member_id = m1) = 'pending', 'report pending';

  begin
    perform public.approve_closing_request(req, 'G-2');
    raise exception 'agent approved a report';
  exception when insufficient_privilege then null;
  end;

  raise notice 'agent A dues checks passed';
end $$;

-- Agent B sees only M3.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000f003', true);
do $$
declare g record;
begin
  select * into g from public.agent_closing_groups();
  assert g.member_count = 1 and g.due_count = 1 and g.to_collect = 100, 'B: ' || row_to_json(g)::text;
  assert (select count(*) from public.agent_closing_requests()) = 0, 'B sees no reports from A';
  raise notice 'agent B dues checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Owner: the dues list matches the count by hand; deciding on reports
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000f001', true);

do $$
declare
  y1 constant uuid := '00000000-0000-0000-0000-0000000f0001';
  m1 constant uuid := '00000000-0000-0000-0000-0000000f0021';
  case_id uuid;
begin
  assert (select count(*) from public.member_dues where yojna_id = y1 and closing_group = 'G-1') = 3,
    'G-1 lists 3 members';
  assert (select count(*) from public.member_dues where closing_group = 'G-1' and due = 0) = 1, 'one paid';
  assert (select count(*) from public.member_dues where closing_group = 'G-1' and due > 0 and pending > 0) = 1,
    'one pending';
  assert (select count(*) from public.member_dues where closing_group = 'G-1' and due > 0 and pending = 0) = 1,
    'one due';
  assert (select sum(due) from public.member_dues where closing_group = 'G-1') = 200, '200 unpaid';
  assert (select count(*) from public.closing_groups where yojna_id = y1) = 1, 'one group in Y1';

  -- Approving the agent's receipt settles M2.
  perform public.approve_payment((select id from dt where key = 'p_m2'));
  assert (select sum(due) from public.member_dues where closing_group = 'G-1') = 100, '100 unpaid after approval';

  -- A cancelled receipt no longer pays the due.
  perform public.cancel_payment((select id from dt where key = 'p_m2'), 'Test');
  assert (select sum(due) from public.member_dues where closing_group = 'G-1') = 200, 'cancelled receipt is due again';

  -- Approving a report creates the case and closes the member.
  begin
    perform public.approve_closing_request((select id from dt where key = 'req_m1'), '  ');
    raise exception 'approved without a group';
  exception when raise_exception then null;
  end;
  case_id := public.approve_closing_request((select id from dt where key = 'req_m1'), 'G-2');
  assert (select claim_amount from public.closing_cases where id = case_id) = 50000, 'claim from the Yojna';
  assert (select closing_date from public.closing_cases where id = case_id) = current_date - 3, 'closing date = date of death';
  assert (select nominee_name from public.closing_cases where id = case_id) = 'Nominee One', 'nominee copied';
  assert (select status from public.members where id = m1) = 'closed', 'member closed';
  assert (select closing_case_id from public.closing_requests where id = (select id from dt where key = 'req_m1')) = case_id,
    'report linked to the case';
  begin
    perform public.approve_closing_request((select id from dt where key = 'req_m1'), 'G-2');
    raise exception 'report approved twice';
  exception when raise_exception then null;
  end;

  begin
    perform public.reject_closing_request((select id from dt where key = 'req_m2'), '');
    raise exception 'rejected without a reason';
  exception when raise_exception then null;
  end;
  perform public.reject_closing_request((select id from dt where key = 'req_m2'), 'Certificate unreadable');

  -- M1 is closed now, so G-1 lists M2 and M3 only.
  assert (select count(*) from public.member_dues where closing_group = 'G-1') = 2, 'closed member leaves the dues list';

  raise notice 'owner dues checks passed';
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000f002', true);
do $$
begin
  assert (select decision_note from public.agent_closing_requests()
           where member_id = '00000000-0000-0000-0000-0000000f0022') = 'Certificate unreadable',
    'agent sees the rejection reason';
  assert (select status from public.agent_closing_requests()
           where member_id = '00000000-0000-0000-0000-0000000f0021') = 'approved', 'agent sees the approval';
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
    perform public.agent_closing_groups();
    raise exception 'anon called agent_closing_groups';
  exception when insufficient_privilege then null;
  end;
  begin
    perform 1 from public.member_dues;
    raise exception 'anon read member_dues';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.reject_closing_request(gen_random_uuid(), 'x');
    raise exception 'anon called reject_closing_request';
  exception when insufficient_privilege then null;
  end;
  raise notice 'anon checks passed';
end $$;

reset role;
rollback;
