-- Phase 13 (IMPLEMENTATION_PLAN §11), with the rules of
-- 20260928000300_closing_per_case.sql: dues per closing, contributions linked
-- to a closing, agents reporting a closing. Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/dues_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   f001 owner   f002 agent A (Y1)   f003 agent B (Y1)
--
-- Two closings in Y1, both in group G-1: C1 for D1 (200 days ago) and C2 for
-- D2 (190 days ago). Each is collected on its own. Who owes, by hand:
--   M1  agent A, paid 100 for C2                    → owes C1
--   M2  agent A, agent collects 100 for C1 below    → owes C1 (pending), C2
--   M3  agent B, nothing                            → owes C1, C2
--   M4  agent A, added to the app after both closings, although its join
--       date is earlier                             → owes nothing
--   M5  agent A, inactive                           → owes nothing
--   D1  agent A, stays active after their closing   → owes C2, not C1
--   D2  agent B, likewise                           → owes C1, not C2
--   X1  Y2 member                                   → owes nothing
-- So C1 has 4 members (M1 M2 M3 D2), C2 has 4 (M1 M2 M3 D1): 700 unpaid.
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

-- M4 was typed in after both closings were created.
update public.members set created_at = now() + interval '1 hour'
 where id = '00000000-0000-0000-0000-0000000f0024';

-- Office receipt for M1, for C2.
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
  d1 constant uuid := '00000000-0000-0000-0000-0000000f0026';
  c1 constant uuid := '00000000-0000-0000-0000-0000000f0031';
  c2 constant uuid := '00000000-0000-0000-0000-0000000f0032';
  g record; r jsonb; req uuid;
begin
  -- Views follow table access: nothing for an agent.
  assert (select count(*) from public.member_dues) = 0, 'agent reads member_dues directly';

  -- One row per closing, although both are in G-1; newest first.
  assert (select array_agg(closing_case_id) from public.agent_closing_groups()) = array[c2, c1],
    'one row per closing';
  select * into g from public.agent_closing_groups() where closing_case_id = c2;
  assert g.closing_group = 'G-1' and g.case_count = 1 and g.beneficiary_name = 'Dues D2', 'C2 row';
  assert g.member_count = 3 and g.paid_count = 1 and g.due_count = 2 and g.pending_count = 0
     and g.to_collect = 200, 'C2 before collecting: ' || row_to_json(g)::text;
  select * into g from public.agent_closing_groups() where closing_case_id = c1;
  assert g.member_count = 2 and g.paid_count = 0 and g.due_count = 2 and g.to_collect = 200,
    'C1 before collecting: ' || row_to_json(g)::text;

  assert (select array_agg(member_id) from public.agent_closing_dues(c1)) = array[m1, m2],
    'A sees M1 and M2 for C1; not B''s member, not D1 whose closing it is';
  assert (select beneficiary_name from public.agent_closing_dues(c1) limit 1) = 'Dues D1', 'C1 is for D1';
  assert (select due from public.agent_member_dues(m1) where closing_case_id = c2) = 0, 'M1 paid for C2';
  assert (select due from public.agent_member_dues(m1) where closing_case_id = c1) = 100, 'M1 still owes C1';
  assert (select count(*) from public.agent_member_dues(m4)) = 0, 'M4 was added after the closings';
  assert (select array_agg(closing_case_id) from public.agent_member_dues(d1)) = array[c2],
    'D1 pays for the other closing, not their own';

  -- Collect from M2 for C1.
  r := public.agent_record_payment(jsonb_build_object(
    'member_id', m2, 'amount', 100, 'closing_case_id', c1));
  insert into dt values ('p_m2', (r ->> 'id')::uuid);
  assert (select closing_group from public.agent_payments() where id = (r ->> 'id')::uuid) = 'G-1',
    'receipt shows its closing group';
  assert (select member_phone from public.agent_payments() where id = (r ->> 'id')::uuid) = '9700000002',
    'receipt has the member phone';

  select * into g from public.agent_closing_groups() where closing_case_id = c1;
  assert g.paid_count = 0 and g.pending_count = 1 and g.due_count = 1 and g.to_collect = 100,
    'C1 after collecting: ' || row_to_json(g)::text;
  select * into g from public.agent_closing_groups() where closing_case_id = c2;
  assert g.to_collect = 200, 'paying C1 does not pay C2: ' || row_to_json(g)::text;

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
    raise exception 'collected from a member added after the closing';
  exception when raise_exception then
    if sqlerrm <> 'This member does not owe for that closing.' then raise; end if;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', d1, 'amount', 100, 'closing_case_id', c1));
    raise exception 'collected from a member for their own closing';
  exception when raise_exception then
    if sqlerrm <> 'This member does not owe for that closing.' then raise; end if;
  end;
  begin
    perform public.agent_member_dues(m3);
    raise exception 'agent read another agent''s member dues';
  exception when raise_exception then
    if sqlerrm <> 'Member not found.' then raise; end if;
  end;

  -- Reporting closings.
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
    raise exception 'report without a Cloudinary proof accepted';
  exception when raise_exception then
    if sqlerrm <> 'Upload the proof document.' then raise; end if;
  end;
  begin
    perform public.agent_request_closing(jsonb_build_object('member_id', m1, 'date_of_death', current_date + 1,
      'certificate_url', 'https://res.cloudinary.com/demo/image/upload/c.jpg'));
    raise exception 'future event date accepted';
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
  -- B has M3 and D2: both owe C1; only M3 owes C2, which is D2's.
  select * into g from public.agent_closing_groups()
   where closing_case_id = '00000000-0000-0000-0000-0000000f0031';
  assert g.member_count = 2 and g.due_count = 2 and g.to_collect = 200, 'B C1: ' || row_to_json(g)::text;
  select * into g from public.agent_closing_groups()
   where closing_case_id = '00000000-0000-0000-0000-0000000f0032';
  assert g.member_count = 1 and g.due_count = 1 and g.to_collect = 100, 'B C2: ' || row_to_json(g)::text;
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
  -- Each closing is collected on its own: 4 members each, 700 unpaid.
  assert (select count(*) from public.member_dues where closing_case_id = '00000000-0000-0000-0000-0000000f0031') = 4,
    'C1 lists 4 members';
  assert (select count(*) from public.member_dues where closing_case_id = '00000000-0000-0000-0000-0000000f0032') = 4,
    'C2 lists 4 members';
  assert (select count(*) from public.member_dues where yojna_id = y1 and due = 0) = 1, 'one paid (M1 for C2)';
  assert (select count(*) from public.member_dues where yojna_id = y1 and due > 0 and pending > 0) = 1,
    'one pending (M2 for C1)';
  assert (select sum(due) from public.member_dues where yojna_id = y1) = 700, '700 unpaid';
  assert (select status from public.members where id = '00000000-0000-0000-0000-0000000f0026') = 'active',
    'a closing leaves its member active';

  -- The office's Dues page: every active or inactive Y1 member, most owed
  -- first, then by name.
  assert (select array_agg(name) from public.office_member_dues(y1))
       = array['Dues M2', 'Dues M3', 'Dues D1', 'Dues D2', 'Dues M1', 'Dues M4', 'Dues M5'],
    'office dues list: ' || (select array_agg(name)::text from public.office_member_dues(y1));
  assert (select (closings_owed, due, pending, contributed)
            from public.office_member_dues(y1) where name = 'Dues M2')
       = (2::bigint, 200::numeric, 100::numeric, 0::numeric), 'M2 owes 200, 100 of it waiting';
  assert (select (closings_owed, due, contributed, last_contribution)
            from public.office_member_dues(y1) where name = 'Dues M1')
       = (1::bigint, 100::numeric, 100::numeric, current_date), 'M1 paid C2 today and owes C1';
  assert (select count(*) from public.office_member_dues(y1, p_owing => true)) = 5, 'five owe';
  assert (select count(*) from public.office_member_dues(y1, p_owing => false)) = 2, 'two owe nothing';
  assert (select count(*) from public.office_member_dues(y1, p_agent_id => '00000000-0000-0000-0000-0000000f0012')) = 2,
    'agent B has M3 and D2';
  assert (select count(*) from public.office_member_dues(y1, 'dues m3')) = 1, 'search by name';
  assert (select (member_count, owing_count, due, pending, contributed) from public.office_dues_totals(y1))
       = (7::bigint, 5::bigint, 700::numeric, 100::numeric, 100::numeric), 'office dues totals: ' || (select row_to_json(t)::text from public.office_dues_totals(y1) t);
  assert (select closed_members from public.dashboard_stats(y1)) = 2, 'two members have a closing';

  -- Approving the agent's receipt settles M2 for C1.
  perform public.approve_payment((select id from dt where key = 'p_m2'));
  assert (select sum(due) from public.member_dues where yojna_id = y1) = 600, '600 unpaid after approval';

  -- A cancelled receipt no longer pays the due.
  perform public.cancel_payment((select id from dt where key = 'p_m2'), 'Test');
  assert (select sum(due) from public.member_dues where yojna_id = y1) = 700, 'cancelled receipt is due again';

  -- Approving a report creates the case; the member stays active.
  begin
    perform public.approve_closing_request((select id from dt where key = 'req_m1'), '  ');
    raise exception 'approved without a group';
  exception when raise_exception then null;
  end;
  case_id := public.approve_closing_request((select id from dt where key = 'req_m1'), 'G-2');
  assert (select claim_amount from public.closing_cases where id = case_id) = 50000, 'claim from the Yojna';
  assert (select closing_date from public.closing_cases where id = case_id) = current_date - 3, 'closing date = event date';
  assert (select nominee_name from public.closing_cases where id = case_id) = 'Nominee One', 'nominee copied';
  assert (select status from public.members where id = m1) = 'active', 'member stays active';
  assert (select closing_group from public.members where id = m1) = 'G-2', 'member shows their closing';
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

  -- Everyone in the app before M1's closing owes for it, except M1: M2 M3 D1
  -- D2. M4 was added later. M1 still owes for C1.
  assert (select count(*) from public.member_dues where closing_case_id = case_id) = 4,
    'new closing: ' || (select count(*) from public.member_dues where closing_case_id = case_id);
  assert not exists (select 1 from public.member_dues where closing_case_id = case_id and member_id = m1),
    'M1 does not pay for their own closing';
  assert (select count(*) from public.member_dues where closing_group = 'G-1') = 8, 'G-1 unchanged';

  -- Deleting the case keeps the member active and clears their closing.
  delete from public.closing_cases where id = case_id;
  assert (select (status, closing_group) from public.members where id = m1) = ('active'::public.member_status, null::text),
    'deleted closing cleared';

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
  begin
    perform public.office_member_dues();
    raise exception 'agent read the office dues list';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.office_dues_totals();
    raise exception 'agent read the office dues totals';
  exception when insufficient_privilege then null;
  end;
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
    perform public.office_member_dues();
    raise exception 'anon called office_member_dues';
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
