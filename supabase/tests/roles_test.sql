-- Phase 10 (IMPLEMENTATION_PLAN §11.3–11.4): what each role can read and change.
-- Runs inside a transaction that is rolled back, so it is safe on staging:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/roles_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as the table owner, so row-level security does not apply)
-- ---------------------------------------------------------------------------
--   b001 owner          b004 agent A2            b007 member M2, profile off
--   b002 staff          b005 agent A3 (agent off) b008 no profile
--   b003 agent A1       b006 member M1           b009 staff, profile off
--                                                b010 member M3 (pending)
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000b0' || lpad(g::text, 2, '0'))::uuid,
       'user' || g || '@test.local'
  from generate_series(1, 10) g;

insert into public.yojnas (id, name, code, contribution_amount)
values ('00000000-0000-0000-0000-0000000d0001', 'भूमिका परीक्षण', 'ROLQ', 100);

insert into public.agents (id, code, name, is_active) values
  ('00000000-0000-0000-0000-0000000d0011', '', 'Agent A1', true),
  ('00000000-0000-0000-0000-0000000d0012', '', 'Agent A2', true),
  ('00000000-0000-0000-0000-0000000d0013', '', 'Agent A3', false);

insert into public.members (id, yojna_id, name, primary_phone, agent_id, status) values
  ('00000000-0000-0000-0000-0000000d0021', '00000000-0000-0000-0000-0000000d0001',
   'सदस्य एम1', '9700000001', '00000000-0000-0000-0000-0000000d0011', 'active'),
  ('00000000-0000-0000-0000-0000000d0022', '00000000-0000-0000-0000-0000000d0001',
   'सदस्य एम2', '9700000002', '00000000-0000-0000-0000-0000000d0012', 'active'),
  ('00000000-0000-0000-0000-0000000d0023', '00000000-0000-0000-0000-0000000d0001',
   'सदस्य एम3', '9700000003', '00000000-0000-0000-0000-0000000d0011', 'pending');

insert into public.payments (id, receipt_no, member_id, yojna_id, amount, agent_id) values
  ('00000000-0000-0000-0000-0000000d0031', '', '00000000-0000-0000-0000-0000000d0021',
   '00000000-0000-0000-0000-0000000d0001', 100, '00000000-0000-0000-0000-0000000d0011');

insert into public.profiles (user_id, role, name, agent_id, member_id, is_active) values
  ('00000000-0000-0000-0000-00000000b001', 'owner',  'Owner',   null, null, true),
  ('00000000-0000-0000-0000-00000000b002', 'staff',  'Staff',   null, null, true),
  ('00000000-0000-0000-0000-00000000b003', 'agent',  'Agent 1', '00000000-0000-0000-0000-0000000d0011', null, true),
  ('00000000-0000-0000-0000-00000000b004', 'agent',  'Agent 2', '00000000-0000-0000-0000-0000000d0012', null, true),
  ('00000000-0000-0000-0000-00000000b005', 'agent',  'Agent 3', '00000000-0000-0000-0000-0000000d0013', null, true),
  ('00000000-0000-0000-0000-00000000b006', 'member', 'Member 1', null, '00000000-0000-0000-0000-0000000d0021', true),
  ('00000000-0000-0000-0000-00000000b007', 'member', 'Member 2', null, '00000000-0000-0000-0000-0000000d0022', false),
  ('00000000-0000-0000-0000-00000000b009', 'staff',  'Old Staff', null, null, false),
  ('00000000-0000-0000-0000-00000000b010', 'member', 'Member 3', null, '00000000-0000-0000-0000-0000000d0023', true);

insert into public.notifications (user_id, type, title) values
  ('00000000-0000-0000-0000-00000000b001', 'test', 'For owner'),
  ('00000000-0000-0000-0000-00000000b002', 'test', 'For staff'),
  ('00000000-0000-0000-0000-00000000b003', 'test', 'For agent');

do $$
declare r record;
begin
  -- A pending member has no number and still shows up in search.
  select reg_no, search_text into r from public.members
   where id = '00000000-0000-0000-0000-0000000d0023';
  assert r.reg_no is null, 'pending member got a reg no: ' || r.reg_no;
  assert r.search_text like '%एम3%', 'pending member search text: ' || coalesce(r.search_text, 'null');

  -- Active members still need a number.
  begin
    update public.members set reg_no = null where id = '00000000-0000-0000-0000-0000000d0021';
    raise exception 'active member without reg no was accepted';
  exception when check_violation then null;
  end;

  -- The role decides which record a profile links to.
  begin
    insert into public.profiles (user_id, role) values ('00000000-0000-0000-0000-00000000b008', 'agent');
    raise exception 'agent profile without an agent was accepted';
  exception when check_violation then null;
  end;
  begin
    insert into public.profiles (user_id, role, agent_id)
    values ('00000000-0000-0000-0000-00000000b008', 'staff', '00000000-0000-0000-0000-0000000d0012');
    raise exception 'staff profile linked to an agent was accepted';
  exception when check_violation then null;
  end;

  -- One open closing request per member.
  insert into public.closing_requests (member_id, date_of_death)
  values ('00000000-0000-0000-0000-0000000d0022', current_date);
  begin
    insert into public.closing_requests (member_id, date_of_death)
    values ('00000000-0000-0000-0000-0000000d0022', current_date);
    raise exception 'second pending closing request was accepted';
  exception when unique_violation then null;
  end;

  -- Commission is per calendar month.
  begin
    insert into public.commission_payouts (agent_id, month, amount)
    values ('00000000-0000-0000-0000-0000000d0011', date '2026-09-15', 10);
    raise exception 'mid-month commission row was accepted';
  exception when check_violation then null;
  end;

  -- Agents with money records cannot be deleted, only deactivated.
  insert into public.cash_handovers (agent_id, amount) values ('00000000-0000-0000-0000-0000000d0012', 500);
  begin
    delete from public.agents where id = '00000000-0000-0000-0000-0000000d0012';
    raise exception 'agent with a cash handover was deleted';
  exception when foreign_key_violation then null;
  end;

  assert (select source from public.payments where id = '00000000-0000-0000-0000-0000000d0031') = 'admin',
    'payment source defaults to admin';

  raise notice 'fixture and constraint checks passed';
end $$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Staff: daily work, no deletes, no scheme or agent changes, no audit log
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b002', true);

do $$
declare
  n int; r text; m uuid;
  y constant uuid := '00000000-0000-0000-0000-0000000d0001';
begin
  assert public.my_role() = 'staff', 'staff role';
  assert public.is_admin() and not public.is_owner(), 'staff is admin, not owner';
  assert public.my_agent_id() is null and public.my_member_id() is null, 'staff has no links';
  assert (select role from public.my_profile()) = 'staff', 'staff my_profile';

  assert (select count(*) from public.members) = 3, 'staff sees members';
  assert (select count(*) from public.agents) = 3, 'staff sees agents';
  assert (select count(*) from public.profiles) = 9, 'staff sees profiles';
  assert (select count(*) from public.admins) = 2, 'admins view: active owner and staff';
  assert (select role from public.admins where user_id = auth.uid()) = 'STAFF', 'admins view role';
  assert (select count(*) from public.audit_log) = 0, 'staff cannot read the audit log';
  assert (select count(*) from public.notifications) = 1, 'staff sees only own notifications';

  -- Adds and approves members; the number is issued on approval.
  insert into public.members (yojna_id, name, primary_phone, status)
  values (y, 'Pending One', '9700000011', 'pending') returning id into m;
  insert into public.members (yojna_id, name, primary_phone, status)
  values (y, 'Pending Two', '9700000012', 'pending');
  assert (select count(*) from public.search_members(y, 'pending one')) = 1, 'search finds pending';
  update public.members set status = 'active' where id = m returning reg_no into r;
  assert r ~ ('^ROLQ-' || extract(year from now() at time zone 'Asia/Kolkata')::int || '-\d{4}$'),
    'reg no on approval: ' || coalesce(r, 'null');

  -- A new active member still gets its number straight away.
  insert into public.members (yojna_id, reg_no, name, primary_phone)
  values (y, '', 'Direct', '9700000013') returning reg_no into r;
  assert r like 'ROLQ-%', 'direct reg no: ' || coalesce(r, 'null');

  insert into public.payments (receipt_no, member_id, yojna_id, amount)
  values ('', m, y, 100);
  update public.payments set note = 'checked' where id = '00000000-0000-0000-0000-0000000d0031';
  get diagnostics n = row_count;
  assert n = 1, 'staff edits payments';

  insert into public.announcements (title) values ('Staff notice');
  update public.notifications set read_at = now();
  get diagnostics n = row_count;
  assert n = 1, 'staff marks own notification read: ' || n;

  -- No deletes.
  delete from public.payments where id = '00000000-0000-0000-0000-0000000d0031';
  get diagnostics n = row_count;
  assert n = 0, 'staff deleted a payment';
  delete from public.members where id = m;
  get diagnostics n = row_count;
  assert n = 0, 'staff deleted a member';

  -- Schemes, agents and commission are owner-only.
  update public.yojnas set description = 'x' where id = y;
  get diagnostics n = row_count;
  assert n = 0, 'staff edited a scheme';
  begin
    insert into public.yojnas (name, code) values ('Staff scheme', 'STFQ');
    raise exception 'staff added a scheme';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.agents (code, name) values ('', 'Staff agent');
    raise exception 'staff added an agent';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.commission_payouts (agent_id, month, amount)
    values ('00000000-0000-0000-0000-0000000d0011', date '2026-09-01', 10);
    raise exception 'staff added a commission payout';
  exception when insufficient_privilege then null;
  end;

  -- Profiles and notifications are not written from the app.
  begin
    insert into public.profiles (user_id, role) values ('00000000-0000-0000-0000-00000000b008', 'owner');
    raise exception 'staff created a profile';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.notifications set title = 'changed';
    raise exception 'staff rewrote a notification';
  exception when insufficient_privilege then null;
  end;

  raise notice 'staff checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Owner: everything
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b001', true);

do $$
declare n int; p uuid;
begin
  assert public.my_role() = 'owner' and public.is_admin() and public.is_owner(), 'owner role';
  assert (select count(*) from public.audit_log) > 0, 'owner reads the audit log';
  assert exists (select 1 from public.audit_log where table_name = 'profiles' and row_id is not null),
    'profiles are audited by user_id';

  update public.yojnas set description = 'owner edit' where id = '00000000-0000-0000-0000-0000000d0001';
  get diagnostics n = row_count;
  assert n = 1, 'owner edits a scheme';

  insert into public.commission_payouts (agent_id, month, amount)
  values ('00000000-0000-0000-0000-0000000d0011', date '2026-09-01', 10);

  insert into public.payments (receipt_no, member_id, yojna_id, amount)
  values ('', '00000000-0000-0000-0000-0000000d0022', '00000000-0000-0000-0000-0000000d0001', 5)
  returning id into p;
  delete from public.payments where id = p;
  get diagnostics n = row_count;
  assert n = 1, 'owner deletes a payment';

  raise notice 'owner checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Agents: no direct table access at all (later phases add functions)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b003', true);

do $$
declare t text; n int;
begin
  assert public.my_role() = 'agent', 'agent role';
  assert not public.is_admin() and not public.is_owner(), 'agent is not an admin';
  assert public.my_agent_id() = '00000000-0000-0000-0000-0000000d0011', 'agent 1 id';
  assert public.my_member_id() is null, 'agent has no member id';
  assert (select agent_id from public.my_profile()) = '00000000-0000-0000-0000-0000000d0011', 'agent my_profile';

  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases',
                           'profiles', 'admins', 'counters', 'audit_log', 'cash_handovers',
                           'commission_payouts', 'closing_requests', 'change_requests',
                           'notifications', 'announcements'] loop
    execute format('select count(*) from public.%I', t) into n;
    assert n = 0, format('agent can read %s (%s rows)', t, n);
  end loop;

  assert (select total_members from public.dashboard_stats()) = 0, 'agent sees stats';
  assert (select count(*) from public.search_members()) = 0, 'agent searches members';

  begin
    perform 1 from public.lookup_attempts;
    raise exception 'agent can read lookup_attempts';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.members (yojna_id, reg_no, name, primary_phone)
    values ('00000000-0000-0000-0000-0000000d0001', '', 'Agent direct', '9700000021');
    raise exception 'agent inserted a member directly';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.payments (receipt_no, member_id, yojna_id, amount)
    values ('', '00000000-0000-0000-0000-0000000d0021', '00000000-0000-0000-0000-0000000d0001', 100);
    raise exception 'agent inserted a payment directly';
  exception when insufficient_privilege then null;
  end;

  update public.members set name = 'hacked' where id = '00000000-0000-0000-0000-0000000d0021';
  get diagnostics n = row_count;
  assert n = 0, 'agent edited a member directly';

  raise notice 'agent checks passed';
end $$;

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b004', true);
do $$
begin
  assert public.my_agent_id() = '00000000-0000-0000-0000-0000000d0012', 'agent 2 id';
end $$;

-- Deactivated agent record: treated as signed out.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b005', true);
do $$
begin
  assert public.my_role() is null, 'inactive agent still has a role';
  assert public.my_agent_id() is null, 'inactive agent still has an agent id';
  assert not exists (select 1 from public.my_profile()), 'inactive agent my_profile';
end $$;

-- ---------------------------------------------------------------------------
-- Members: no direct table access; only their own id
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b006', true);

do $$
declare t text; n int;
begin
  assert public.my_role() = 'member', 'member role';
  assert public.my_member_id() = '00000000-0000-0000-0000-0000000d0021', 'member 1 id';
  assert public.my_agent_id() is null and not public.is_admin(), 'member has no admin or agent access';

  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases',
                           'profiles', 'admins', 'notifications', 'announcements'] loop
    execute format('select count(*) from public.%I', t) into n;
    assert n = 0, format('member can read %s (%s rows)', t, n);
  end loop;

  raise notice 'member checks passed';
end $$;

-- Deactivated profile, pending member, inactive staff, no profile: no role.
do $$
declare u text;
begin
  foreach u in array array['00000000-0000-0000-0000-00000000b007', '00000000-0000-0000-0000-00000000b010',
                           '00000000-0000-0000-0000-00000000b009', '00000000-0000-0000-0000-00000000b008'] loop
    perform set_config('request.jwt.claim.sub', u, true);
    assert public.my_role() is null, 'user without access has a role: ' || u;
    assert not public.is_admin(), 'user without access is admin: ' || u;
    assert public.my_member_id() is null and public.my_agent_id() is null, 'user without access has links: ' || u;
    assert (select count(*) from public.admins) = 0, 'user without access reads admins: ' || u;
    assert (select count(*) from public.members) = 0, 'user without access reads members: ' || u;
  end loop;
  raise notice 'no-access checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Anon (logged out): no tables, no role helpers
-- ---------------------------------------------------------------------------
reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

do $$
declare t text;
begin
  foreach t in array array['profiles', 'admins', 'cash_handovers', 'commission_payouts',
                           'closing_requests', 'change_requests', 'notifications',
                           'announcements', 'lookup_attempts'] loop
    begin
      execute format('select 1 from public.%I limit 1', t);
      raise exception 'anon can select from %', t;
    exception when insufficient_privilege then null;
    end;
  end loop;

  begin
    perform public.my_role();
    raise exception 'anon can call my_role';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.my_profile();
    raise exception 'anon can call my_profile';
  exception when insufficient_privilege then null;
  end;

  raise notice 'anon checks passed';
end $$;

reset role;
rollback;
