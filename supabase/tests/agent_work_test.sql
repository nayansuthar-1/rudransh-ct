-- Phase 12 (IMPLEMENTATION_PLAN §11): agents add members and record payments;
-- admins approve, reject, cancel and reassign. Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/agent_work_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   c001 owner   c002 staff   c003 agent A1 (Y1 only)   c004 agent A2 (all)
--   c005 member M1
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000c0' || lpad(g::text, 2, '0'))::uuid, 'aw' || g || '@test.local'
  from generate_series(1, 5) g;

insert into public.yojnas (id, name, code, contribution_amount, registration_fee) values
  ('00000000-0000-0000-0000-0000000e0001', 'Agent Work One', 'AWQA', 100, 50),
  ('00000000-0000-0000-0000-0000000e0002', 'Agent Work Two', 'AWQB', 200, 50);

insert into public.agents (id, code, name, yojna_ids) values
  ('00000000-0000-0000-0000-0000000e0011', '', 'Agent A1', array['00000000-0000-0000-0000-0000000e0001'::uuid]),
  ('00000000-0000-0000-0000-0000000e0012', '', 'Agent A2', '{}');

insert into public.members (id, yojna_id, name, primary_phone, aadhaar, agent_id) values
  ('00000000-0000-0000-0000-0000000e0021', '00000000-0000-0000-0000-0000000e0001',
   'Existing One', '9600000001', '123456789012', '00000000-0000-0000-0000-0000000e0011'),
  ('00000000-0000-0000-0000-0000000e0022', '00000000-0000-0000-0000-0000000e0002',
   'Existing Two', '9600000002', '', '00000000-0000-0000-0000-0000000e0012');

insert into public.profiles (user_id, role, agent_id, member_id) values
  ('00000000-0000-0000-0000-00000000c001', 'owner',  null, null),
  ('00000000-0000-0000-0000-00000000c002', 'staff',  null, null),
  ('00000000-0000-0000-0000-00000000c003', 'agent',  '00000000-0000-0000-0000-0000000e0011', null),
  ('00000000-0000-0000-0000-00000000c004', 'agent',  '00000000-0000-0000-0000-0000000e0012', null),
  ('00000000-0000-0000-0000-00000000c005', 'member', null, '00000000-0000-0000-0000-0000000e0021');

-- Shared ids between the blocks below.
create temporary table aw (key text primary key, id uuid) on commit drop;
grant all on aw to authenticated;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Agent A1: own members, own schemes, pending work
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c003', true);

do $$
declare
  y1 constant uuid := '00000000-0000-0000-0000-0000000e0001';
  y2 constant uuid := '00000000-0000-0000-0000-0000000e0002';
  m1 constant uuid := '00000000-0000-0000-0000-0000000e0021';
  m2 constant uuid := '00000000-0000-0000-0000-0000000e0022';
  keep uuid; drop_ uuid; r jsonb; p1 uuid; n int;
begin
  assert (select count(*) from public.agent_yojnas()) = 1, 'A1 works on one scheme';
  assert (select count(*) from public.agent_members()) = 1, 'A1 sees one member';
  assert (select aadhaar_last4 from public.agent_members()) = '9012', 'Aadhaar masked to last 4';
  assert (select count(*) from public.agent_members('existing one')) = 1, 'agent member search';

  keep := public.agent_add_member(jsonb_build_object(
    'yojna_id', y1, 'name', 'New Keep', 'primary_phone', '9600000011', 'gender', 'female'));
  drop_ := public.agent_add_member(jsonb_build_object(
    'yojna_id', y1, 'name', 'New Drop', 'primary_phone', '9600000012'));
  insert into aw values ('keep', keep), ('drop', drop_);

  assert (select status from public.agent_members() where id = keep) = 'pending', 'new member is pending';
  assert (select reg_no from public.agent_members() where id = keep) is null, 'pending member has no reg no';
  assert (select count(*) from public.agent_members(p_status => 'pending')) = 2, 'status filter';

  begin
    perform public.agent_add_member(jsonb_build_object('yojna_id', y2, 'name', 'Wrong', 'primary_phone', '9600000013'));
    raise exception 'agent enrolled in a scheme not assigned to them';
  exception when raise_exception then
    if sqlerrm not like 'You cannot enrol%' then raise; end if;
  end;
  begin
    perform public.agent_add_member(jsonb_build_object('yojna_id', y1, 'name', 'Bad phone', 'primary_phone', '123'));
    raise exception 'short phone accepted';
  exception when check_violation then null;
  end;

  perform public.agent_update_contact(m1, jsonb_build_object('village', 'Balotra'));
  begin
    perform public.agent_update_contact(m2, jsonb_build_object('village', 'Hacked'));
    raise exception 'agent edited another agent''s member';
  exception when raise_exception then
    if sqlerrm <> 'Member not found.' then raise; end if;
  end;

  -- Payments wait for approval and carry a receipt number already.
  r := public.agent_record_payment(jsonb_build_object('member_id', m1, 'amount', 100, 'mode', 'upi', 'reference', 'UTR1'));
  p1 := (r ->> 'id')::uuid;
  assert r ->> 'receipt_no' like 'RCP-%', 'receipt number issued: ' || r::text;
  insert into aw values ('p1', p1);

  r := public.agent_record_payment(jsonb_build_object('member_id', keep, 'amount', 50, 'kind', 'registration'));
  insert into aw values ('reg_keep', (r ->> 'id')::uuid);
  r := public.agent_record_payment(jsonb_build_object('member_id', drop_, 'amount', 50, 'kind', 'registration'));
  insert into aw values ('reg_drop', (r ->> 'id')::uuid);
  r := public.agent_record_payment(jsonb_build_object('member_id', m1, 'amount', 100));
  insert into aw values ('p_reject', (r ->> 'id')::uuid);

  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', keep, 'amount', 100));
    raise exception 'contribution for a pending member accepted';
  exception when raise_exception then
    if sqlerrm not like 'Only the registration fee%' then raise; end if;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m1, 'amount', 100, 'kind', 'closingPayout'));
    raise exception 'agent recorded a payout';
  exception when raise_exception then null;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m2, 'amount', 100));
    raise exception 'agent recorded a payment for another agent''s member';
  exception when raise_exception then
    if sqlerrm <> 'Member not found.' then raise; end if;
  end;
  begin
    perform public.agent_record_payment(jsonb_build_object('member_id', m1, 'amount', 100,
      'date', (public.today_ist() + 1)::text));
    raise exception 'future payment date accepted';
  exception when raise_exception then null;
  end;

  assert (select count(*) from public.agent_payments()) = 4, 'A1 sees own receipts';
  assert (select status from public.agent_payments() where id = p1) = 'pending', 'agent payment is pending';

  perform public.agent_request_cancel(p1, 'Wrong member');
  begin
    perform public.agent_request_cancel(p1, 'Again');
    raise exception 'second cancel request accepted';
  exception when raise_exception then null;
  end;

  assert (select pending_members from public.agent_summary()) = 2, 'summary pending members';
  assert (select pending_payments from public.agent_summary()) = 4, 'summary pending payments';
  assert (select pending_amount from public.agent_summary()) = 300, 'summary pending amount';

  -- Still no direct table access, and no admin functions.
  assert (select count(*) from public.members) = 0, 'agent reads members table';
  begin
    perform public.approve_member(keep);
    raise exception 'agent approved a member';
  exception when insufficient_privilege then null;
  end;

  raise notice 'agent A1 checks passed';
end $$;

-- Agent A2 sees only their own member.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c004', true);
do $$
begin
  assert (select count(*) from public.agent_members()) = 1, 'A2 sees one member';
  assert (select name from public.agent_members()) = 'Existing Two', 'A2 sees their member';
  assert (select count(*) from public.agent_payments()) = 0, 'A2 sees no A1 receipts';
  assert (select count(*) from public.agent_yojnas()) = 2, 'A2 with no schemes set works on all';
end $$;

-- A member is not an agent.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c005', true);
do $$
begin
  begin
    perform public.agent_members();
    raise exception 'member called agent_members';
  exception when insufficient_privilege then null;
  end;
end $$;

-- ---------------------------------------------------------------------------
-- Staff: approvals, totals, reassigning
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c002', true);

do $$
declare
  y1 constant uuid := '00000000-0000-0000-0000-0000000e0001';
  keep uuid := (select id from aw where key = 'keep');
  drop_ uuid := (select id from aw where key = 'drop');
  r text; n int;
begin
  -- Pending members are left out of member counts.
  assert (select total_members from public.dashboard_stats(y1)) = 1, 'pending members not counted';
  assert (select member_count from public.members_per_yojna() where yojna_id = y1) = 1, 'per yojna excludes pending';
  assert (select paid from public.payment_totals(y1)) = 0, 'pending payments not paid';
  assert (select pending from public.payment_totals(y1)) = 300, 'pending total';

  begin
    perform public.approve_payment((select id from aw where key = 'reg_keep'));
    raise exception 'payment approved before its member';
  exception when raise_exception then
    if sqlerrm <> 'Approve the member first.' then raise; end if;
  end;

  r := public.approve_member(keep);
  assert r like 'AWQA-%', 'reg no on approval: ' || coalesce(r, 'null');
  begin
    perform public.approve_member(keep);
    raise exception 'member approved twice';
  exception when raise_exception then null;
  end;

  begin
    perform public.reject_member(drop_, '  ');
    raise exception 'reject without reason accepted';
  exception when raise_exception then null;
  end;
  perform public.reject_member(drop_, 'Duplicate of an existing member');
  assert (select status from public.members where id = drop_) = 'inactive', 'rejected member inactive';
  assert (select reg_no from public.members where id = drop_) is null, 'rejected member has no reg no';
  assert (select status from public.payments where id = (select id from aw where key = 'reg_drop')) = 'failed',
    'rejected member''s pending payment failed';

  perform public.approve_payment((select id from aw where key = 'reg_keep'));
  perform public.approve_payment((select id from aw where key = 'p1'));
  assert (select approved_by from public.payments where id = (select id from aw where key = 'p1')) = auth.uid(),
    'approved_by recorded';
  perform public.reject_payment((select id from aw where key = 'p_reject'), 'No money received');
  assert (select paid from public.payment_totals(y1)) = 150, 'approved payments count as paid';
  assert (select total from public.collection_by_agent(y1)
           where agent_id = '00000000-0000-0000-0000-0000000e0011') = 150, 'agent collection';

  -- Staff cannot cancel receipts, but can decline a request.
  begin
    perform public.cancel_payment((select id from aw where key = 'p1'), 'Wrong member');
    raise exception 'staff cancelled a receipt';
  exception when insufficient_privilege then null;
  end;

  -- Making a rejected sign-up active later gives it a number.
  update public.members set status = 'active' where id = drop_ returning reg_no into r;
  assert r like 'AWQA-%', 'reactivated sign-up gets a reg no: ' || coalesce(r, 'null');

  -- Reassigning.
  begin
    perform public.reassign_members('00000000-0000-0000-0000-0000000e0011', '00000000-0000-0000-0000-0000000e0011');
    raise exception 'reassign to the same agent accepted';
  exception when raise_exception then null;
  end;
  n := public.reassign_members('00000000-0000-0000-0000-0000000e0011', '00000000-0000-0000-0000-0000000e0012',
                               array[keep]);
  assert n = 1, 'one member moved: ' || n;

  raise notice 'staff checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Owner: cancelling a receipt removes it from totals
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c001', true);

do $$
declare
  y1 constant uuid := '00000000-0000-0000-0000-0000000e0001';
  p1 uuid := (select id from aw where key = 'p1');
begin
  perform public.cancel_payment(p1, 'Wrong member');
  assert (select paid from public.payment_totals(y1)) = 50, 'cancelled receipt leaves totals';
  assert (select month_collection from public.dashboard_stats(y1)) = 50, 'dashboard leaves out cancelled';
  begin
    perform public.decline_cancel_request(p1);
    raise exception 'declined a request on a cancelled receipt';
  exception when raise_exception then null;
  end;
  raise notice 'owner checks passed';
end $$;

-- The moved member now belongs to A2.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000c004', true);
do $$
begin
  assert (select count(*) from public.agent_members()) = 2, 'A2 sees the moved member';
  raise notice 'reassign checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Anon: no agent or approval functions
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);
do $$
begin
  begin
    perform public.agent_summary();
    raise exception 'anon called agent_summary';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.approve_payment(gen_random_uuid());
    raise exception 'anon called approve_payment';
  exception when insufficient_privilege then null;
  end;
  raise notice 'anon checks passed';
end $$;

reset role;
rollback;
