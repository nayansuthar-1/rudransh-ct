-- Behaviour checks for the schema, triggers and row-level security.
-- Runs inside a transaction that is rolled back, so it is safe on staging:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/database_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- Two users: one invited admin, one signed-in stranger.
with u as (
  insert into auth.users (id, email) values
    ('00000000-0000-0000-0000-00000000a001', 'admin@test.local'),
    ('00000000-0000-0000-0000-00000000a002', 'stranger@test.local')
  returning id
) select count(*) from u;
insert into public.profiles (user_id, role, name, email)
values ('00000000-0000-0000-0000-00000000a001', 'owner', 'Test Admin', 'admin@test.local');

-- ---------------------------------------------------------------------------
-- As admin
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000a001', true);

do $$
declare
  y uuid; a1 uuid; a2 uuid; m1 uuid; m2 uuid; p1 uuid; c1 uuid;
  r text; r2 text; n int; s record;
begin
  assert public.is_admin(), 'admin should pass is_admin()';

  insert into public.yojnas (name, code, contribution_amount, claim_amount)
  values ('परीक्षण योजना', 'TSTQ', 100, 50000) returning id into y;

  -- Agent codes come from the counter.
  insert into public.agents (code, name) values ('', 'Agent One') returning id, code into a1, r;
  insert into public.agents (code, name) values ('', 'Agent Two') returning id, code into a2, r2;
  assert r ~ '^AG-\d{3}$', 'agent code format: ' || r;
  assert split_part(r2, '-', 2)::int = split_part(r, '-', 2)::int + 1, 'agent codes increment';

  -- Registration numbers per scheme per year.
  insert into public.members (yojna_id, reg_no, name, primary_phone, agent_id)
  values (y, '', 'सदस्य एक', '9876543210', a1) returning id, reg_no into m1, r;
  insert into public.members (yojna_id, reg_no, name, primary_phone, agent_id)
  values (y, '', 'सदस्य दो', '9876543211', a1) returning id, reg_no into m2, r2;
  assert r = 'TSTQ-' || extract(year from now() at time zone 'Asia/Kolkata')::int || '-0001', 'first reg no: ' || r;
  assert r2 like '%-0002', 'second reg no: ' || r2;

  -- Phone must be 10 digits.
  begin
    insert into public.members (yojna_id, reg_no, name, primary_phone) values (y, '', 'Bad', '12345');
    raise exception 'short phone was accepted';
  exception when check_violation then null;
  end;

  -- Receipt numbers.
  insert into public.payments (receipt_no, member_id, yojna_id, amount, agent_id)
  values ('', m1, y, 100, a1) returning id, receipt_no into p1, r;
  insert into public.payments (receipt_no, member_id, yojna_id, amount)
  values ('', m1, y, 100) returning receipt_no into r2;
  assert r ~ '^RCP-\d{4,}$', 'receipt format: ' || r;
  assert split_part(r2, '-', 2)::int = split_part(r, '-', 2)::int + 1, 'receipts increment';
  assert (select created_by from public.payments where id = p1) = auth.uid(), 'created_by set';

  begin
    insert into public.payments (receipt_no, member_id, yojna_id, amount) values ('', m1, y, 0);
    raise exception 'zero amount was accepted';
  exception when check_violation then null;
  end;

  -- Closing a case closes the member; deleting it reopens.
  insert into public.closing_cases (member_id, yojna_id, closing_group, claim_amount, collected_amount)
  values (m2, y, 'Group-99', 50000, 20000) returning id into c1;
  select status, closing_group into s from public.members where id = m2;
  assert s.status = 'closed' and s.closing_group = 'Group-99', 'member closed by case';

  select * into s from public.dashboard_stats(y);
  assert s.total_members = 2 and s.closed_members = 1 and s.active_members = 1, 'member counts';
  assert s.pending_claims = 30000, 'pending claims: ' || s.pending_claims;
  assert s.month_collection = 200, 'month collection: ' || s.month_collection;

  delete from public.closing_cases where id = c1;
  select status, closing_group into s from public.members where id = m2;
  assert s.status = 'active' and s.closing_group is null, 'member reopened';

  -- Search and totals.
  assert (select count(*) from public.search_members(y, 'दो')) = 1, 'member search';
  assert (select count(*) from public.search_members(y, '%')) = 0, 'wildcard is literal';
  assert (select count(*) from public.search_payments(y, 'सदस्य एक')) = 2, 'payment search by member';
  assert (select paid from public.payment_totals(y)) = 200, 'payment totals';
  assert (select count(*) from public.search_payments(p_member_id => m1)) = 2, 'payments by member';
  assert (select count(*) from public.search_payments(p_member_id => m2)) = 0, 'no payments for m2';
  assert (select count(*) from public.monthly_collection(y)) = 6, 'six months';
  assert (select total from public.collection_by_agent(y) where agent_id = a1) = 100, 'agent collection';

  -- A member with payments cannot be deleted.
  begin
    delete from public.members where id = m1;
    raise exception 'member with payments was deleted';
  exception when foreign_key_violation then null;
  end;

  -- A closed member without payments can be deleted (case cascades).
  insert into public.closing_cases (member_id, yojna_id, claim_amount) values (m2, y, 1);
  delete from public.members where id = m2;
  assert not exists (select 1 from public.closing_cases where member_id = m2), 'case cascaded';

  -- Deleting an agent unassigns members and payments.
  delete from public.agents where id = a1;
  assert (select agent_id from public.members where id = m1) is null, 'member agent cleared';
  assert (select agent_id from public.payments where id = p1) is null, 'payment agent cleared';

  -- A scheme with members cannot be deleted.
  begin
    delete from public.yojnas where id = y;
    raise exception 'yojna with members was deleted';
  exception when foreign_key_violation then null;
  end;

  -- Deleting a scheme removes it from agents' yojna_ids.
  insert into public.yojnas (name, code) values ('Temp', 'TMPQ') returning id into y;
  update public.agents set yojna_ids = array[y] where id = a2;
  delete from public.yojnas where id = y;
  assert (select cardinality(yojna_ids) from public.agents where id = a2) = 0, 'yojna id removed';

  -- Audit trail, without Aadhaar.
  update public.members set aadhaar = '123456789012' where id = m1;
  select count(*) into n from public.audit_log where row_id = m1;
  assert n >= 2, 'audit rows for member: ' || n;
  assert not exists (
    select 1 from public.audit_log where new_data ? 'aadhaar' or old_data ? 'aadhaar'
  ), 'aadhaar leaked into audit log';

  -- Admins cannot rewrite numbering, the admin list or the audit trail.
  begin
    update public.counters set value = 1 where key = 'RCP';
    raise exception 'authenticated can update counters';
  exception when insufficient_privilege then null;
  end;
  begin
    delete from public.audit_log;
    raise exception 'authenticated can delete audit_log';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.profiles (user_id, role) values ('00000000-0000-0000-0000-00000000a002', 'owner');
    raise exception 'authenticated can add admins';
  exception when insufficient_privilege then null;
  end;

  -- Admins cannot call the counter directly.
  begin
    perform public.next_number('RCP');
    raise exception 'next_number is callable by authenticated';
  exception when insufficient_privilege then null;
  end;

  raise notice 'admin checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- As a signed-in user who is not an admin: sees nothing, changes nothing
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000a002', true);

do $$
declare n int;
begin
  assert not public.is_admin(), 'stranger should fail is_admin()';
  select (select count(*) from public.yojnas) + (select count(*) from public.members)
       + (select count(*) from public.agents) + (select count(*) from public.payments)
       + (select count(*) from public.closing_cases) + (select count(*) from public.admins)
       + (select count(*) from public.audit_log) + (select count(*) from public.counters)
    into n;
  assert n = 0, 'stranger can read rows: ' || n;
  assert (select total_members from public.dashboard_stats()) = 0, 'stranger sees stats';

  begin
    insert into public.yojnas (name, code) values ('Hack', 'HACK');
    raise exception 'stranger inserted a yojna';
  exception when insufficient_privilege then null;
  end;

  raise notice 'non-admin checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- As anon (logged-out browser): no table access at all
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

do $$
declare t text;
begin
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases',
                           'admins', 'counters', 'audit_log'] loop
    begin
      execute format('select 1 from public.%I limit 1', t);
      raise exception 'anon can select from %', t;
    exception when insufficient_privilege then null;
    end;
  end loop;

  begin
    perform public.dashboard_stats();
    raise exception 'anon can call dashboard_stats';
  exception when insufficient_privilege then null;
  end;

  raise notice 'anon checks passed';
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- Numbering past the padding width (as owner, to fast-forward the counter)
-- ---------------------------------------------------------------------------
do $$
declare y uuid; r text;
begin
  assert public.zero_pad(7, 4) = '0007', 'zero_pad padding';
  assert public.zero_pad(10000, 4) = '10000', 'zero_pad truncated';

  insert into public.yojnas (name, code) values ('Big', 'BIGQ') returning id into y;
  insert into public.counters (key, value)
  values ('BIGQ-' || extract(year from now() at time zone 'Asia/Kolkata')::int, 9999);
  insert into public.members (yojna_id, reg_no, name, primary_phone)
  values (y, '', 'दस हज़ार', '9876543219') returning reg_no into r;
  assert r like '%-10000', 'reg no past 9999: ' || r;

  update public.counters set value = 999 where key = 'AG';
  insert into public.agents (code, name) values ('', 'Agent 1000') returning code into r;
  assert r = 'AG-1000', 'agent code past 999: ' || r;

  raise notice 'numbering checks passed';
end $$;

rollback;
