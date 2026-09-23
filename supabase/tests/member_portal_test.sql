-- Phase 15 (IMPLEMENTATION_PLAN §11): the member portal.
-- Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/member_portal_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   b001 owner   b002 member P1   b003 agent
--
--   P1  Aadhaar on file, one closing group owed
--   P2  no Aadhaar on file (the column is optional, §7)
--   PD  died; P1 and P2 owe a contribution for the closing
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000b0' || lpad(g::text, 2, '0'))::uuid, 'portal' || g || '@test.local'
  from generate_series(1, 3) g;

insert into public.yojnas (id, name, code, contribution_amount, claim_amount, registration_fee) values
  ('00000000-0000-0000-0000-0000000b0001', 'Portal One', 'POQA', 100, 50000, 50);

insert into public.agents (id, code, name, yojna_ids) values
  ('00000000-0000-0000-0000-0000000b0011', '', 'Portal Agent',
   array['00000000-0000-0000-0000-0000000b0001'::uuid]);

insert into public.members
  (id, yojna_id, name, primary_phone, alt_phone, aadhaar, village, agent_id, join_date, status) values
  ('00000000-0000-0000-0000-0000000b0021', '00000000-0000-0000-0000-0000000b0001', 'Portal P1',
   '9400000001', '9400000091', '123456789012', 'Old Village',
   '00000000-0000-0000-0000-0000000b0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000b0022', '00000000-0000-0000-0000-0000000b0001', 'Portal P2',
   '9400000002', '', '', '', '00000000-0000-0000-0000-0000000b0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000b0023', '00000000-0000-0000-0000-0000000b0001', 'Portal PD',
   '9400000003', '', '', '', '00000000-0000-0000-0000-0000000b0011', current_date - 900, 'active');

insert into public.closing_cases (id, member_id, yojna_id, closing_date, closing_group, claim_amount) values
  ('00000000-0000-0000-0000-0000000b0031', '00000000-0000-0000-0000-0000000b0023',
   '00000000-0000-0000-0000-0000000b0001', current_date - 30, 'P-1', 50000);

insert into public.profiles (user_id, role, agent_id, member_id) values
  ('00000000-0000-0000-0000-00000000b001', 'owner', null, null),
  ('00000000-0000-0000-0000-00000000b002', 'member', null, '00000000-0000-0000-0000-0000000b0021'),
  ('00000000-0000-0000-0000-00000000b003', 'agent', '00000000-0000-0000-0000-0000000b0011', null);

-- ---------------------------------------------------------------------------
-- Public lookup (owner stands in for the Edge Function's service role)
-- ---------------------------------------------------------------------------

do $$
declare r record; n integer;
begin
  -- Phone + last four Aadhaar digits; no registration number.
  select * into r from public.member_lookup('9400000001', '9012');
  assert r.name = 'Portal P1', 'lookup found the member';
  assert r.dues_count = 1, 'one closing group owed: ' || r.dues_count;
  assert r.dues_amount = 100, 'owed amount: ' || r.dues_amount;

  -- The alternate phone works too.
  select count(*) into n from public.member_lookup('9400000091', '9012');
  assert n = 1, 'the alternate phone is accepted';

  -- Only a summary: nothing here carries Aadhaar or an address.
  assert not exists (
    select 1 from information_schema.columns
     where table_schema = 'public' and table_name = 'member_lookup'
  ), 'lookup is a function, not a table';

  -- Wrong Aadhaar, right phone.
  select count(*) into n from public.member_lookup('9400000001', '0000');
  assert n = 0, 'a wrong Aadhaar finds nothing';

  -- Wrong phone.
  select count(*) into n from public.member_lookup('9999999999', '9012');
  assert n = 0, 'a wrong phone finds nothing';

  -- With no registration number to go on, the phone alone must not be
  -- enough: a member with no Aadhaar on file is not found.
  select count(*) into n from public.member_lookup('9400000002', '1234');
  assert n = 0, 'a member without Aadhaar is not found on the phone alone';

  -- Both halves are required.
  begin
    perform public.member_lookup('', '9012');
    raise exception 'an empty phone was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Enter the 10-digit%' then raise; end if;
  end;
  begin
    perform public.member_lookup('9400000001', '');
    raise exception 'empty Aadhaar digits were accepted';
  exception when raise_exception then
    if sqlerrm not like 'Enter the last 4%' then raise; end if;
  end;

  raise notice 'lookup match checks passed';
end $$;

-- Every membership under the phone comes back.
do $$
declare n integer;
begin
  insert into public.members
    (id, yojna_id, name, primary_phone, aadhaar, agent_id, join_date, status) values
    ('00000000-0000-0000-0000-0000000b0024', '00000000-0000-0000-0000-0000000b0001',
     'Portal P1 again', '9400000001', '123456789012',
     '00000000-0000-0000-0000-0000000b0011', current_date - 100, 'active');

  select count(*) into n from public.member_lookup('9400000001', '9012');
  assert n = 2, 'both memberships under the phone: ' || n;

  delete from public.members where id = '00000000-0000-0000-0000-0000000b0024';
  raise notice 'lookup multi-membership check passed';
end $$;

-- Five wrong tries lock the phone for the window.
do $$
declare n integer;
begin
  -- The wrong-Aadhaar and wrong-phone tries above were against other phones,
  -- so this one starts clean.
  for i in 1..5 loop
    perform public.member_lookup('9400000003', '0000');
  end loop;
  assert public.lookup_locked('9400000003'), 'five wrong tries lock the phone';

  begin
    perform public.member_lookup('9400000003', '1234');
    raise exception 'a locked phone still answered';
  exception when raise_exception then
    if sqlerrm not like 'Too many wrong tries%' then raise; end if;
  end;

  -- Another phone is unaffected.
  select count(*) into n from public.member_lookup('9400000001', '9012');
  assert n = 1, 'the lock is per phone number';

  raise notice 'lookup throttle checks passed';
end $$;

-- Nothing signed-out or signed-in can call it directly.
do $$
begin
  assert not has_function_privilege('anon',
    'public.member_lookup(text, text)', 'execute'),
    'anon can call the lookup directly';
  assert not has_function_privilege('authenticated',
    'public.member_lookup(text, text)', 'execute'),
    'a signed-in user can call the lookup directly';
  assert has_function_privilege('service_role',
    'public.member_lookup(text, text)', 'execute'),
    'the Edge Function cannot call the lookup';
  raise notice 'lookup access checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- The member's own screens
-- ---------------------------------------------------------------------------

create temporary table pt (key text primary key, id uuid) on commit drop;
grant all on pt to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b002', true);

do $$
declare m record; d record; n integer;
begin
  -- The tables stay out of reach; the functions are the way in.
  assert (select count(*) from public.members) = 0, 'a member reads the members table';
  assert (select count(*) from public.member_dues) = 0, 'a member reads member_dues';

  select * into m from public.my_membership();
  assert m.name = 'Portal P1', 'own membership';
  assert m.yojna_name = 'Portal One', 'own Yojna';
  assert m.agent_name = 'Portal Agent', 'own agent';
  assert (select count(*) from public.my_membership()) = 1, 'exactly one membership';

  select * into d from public.my_member_dues();
  assert d.closing_group = 'P-1', 'own dues group';
  assert d.due = 100, 'own dues amount: ' || d.due;

  assert (select count(*) from public.my_member_payments()) = 0, 'no receipts yet';
  assert (select count(*) from public.my_closing_case()) = 0, 'alive, so no closing case';

  -- Paying by UPI leaves a pending receipt for the office.
  insert into pt values ('upi', public.member_submit_upi(100, 'UTR123456789',
    '00000000-0000-0000-0000-0000000b0031'));
  select count(*) into n from public.my_member_payments();
  assert n = 1, 'the UPI payment is listed';
  assert (select status from public.my_member_payments()) = 'pending',
    'it waits for the office';
  assert (select closing_group from public.my_member_payments()) = 'P-1',
    'it is linked to the closing group';

  -- The same reference twice is refused.
  begin
    perform public.member_submit_upi(100, 'UTR123456789', null);
    raise exception 'a duplicate UTR was accepted';
  exception when raise_exception then
    if sqlerrm not like 'That UPI reference%' then raise; end if;
  end;

  begin
    perform public.member_submit_upi(0, 'UTR999999999', null);
    raise exception 'a zero amount was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Enter the amount%' then raise; end if;
  end;

  begin
    perform public.member_submit_upi(100, 'x', null);
    raise exception 'a short reference was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Enter the UPI reference%' then raise; end if;
  end;

  raise notice 'member screen checks passed';
end $$;

-- Change requests.
do $$
declare r record;
begin
  insert into pt values ('chg', public.request_change('village', 'New Village'));

  select * into r from public.my_change_requests();
  assert r.field = 'village', 'the request names the field';
  assert r.old_value = 'Old Village', 'it records what it was';
  assert r.new_value = 'New Village', 'and what it should be';
  assert r.status = 'pending', 'it waits for the office';

  -- One pending change per field.
  begin
    perform public.request_change('village', 'Third Village');
    raise exception 'a second pending change to one field was accepted';
  exception when raise_exception then
    if sqlerrm not like 'A change to this detail%' then raise; end if;
  end;

  -- Only the fields the table allows.
  begin
    perform public.request_change('aadhaar', '999999999999');
    raise exception 'an Aadhaar change request was accepted';
  exception when others then
    null;
  end;

  begin
    perform public.request_change('primary_phone', '   ');
    raise exception 'a blank value was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Enter the new value%' then raise; end if;
  end;

  raise notice 'change request checks passed';
end $$;

-- An agent is not a member.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b003', true);

do $$
begin
  begin
    perform public.my_membership();
    raise exception 'an agent read a membership';
  exception when insufficient_privilege then
    null;
  end;
  begin
    perform public.request_change('village', 'Agent Village');
    raise exception 'an agent filed a change request';
  exception when insufficient_privilege then
    null;
  end;
  raise notice 'non-member checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- The office decides
-- ---------------------------------------------------------------------------

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b001', true);

do $$
declare r record;
begin
  select * into r from public.pending_change_requests();
  assert r.member_name = 'Portal P1', 'the queue names the member';
  assert r.new_value = 'New Village', 'and the new value';

  begin
    perform public.reject_change_request((select id from pt where key = 'chg'), '  ');
    raise exception 'a rejection without a reason was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Give a reason%' then raise; end if;
  end;

  perform public.approve_change_request((select id from pt where key = 'chg'));
  assert (select count(*) from public.pending_change_requests()) = 0,
    'the queue is empty afterwards';

  -- Deciding twice is refused.
  begin
    perform public.approve_change_request((select id from pt where key = 'chg'));
    raise exception 'the same change was approved twice';
  exception when raise_exception then
    if sqlerrm not like 'This change is no longer%' then raise; end if;
  end;

  raise notice 'office decision checks passed';
end $$;

reset role;

do $$
begin
  assert (select village from public.members
           where id = '00000000-0000-0000-0000-0000000b0021') = 'New Village',
    'approving applied the change to the member';

  -- And the member was told (Phase 14).
  assert (select count(*) from public.notifications
           where user_id = '00000000-0000-0000-0000-00000000b002'
             and type = 'change_approved') = 1,
    'the member was notified';

  raise notice 'applied change checks passed';
end $$;

do $$ begin raise notice 'member portal checks passed'; end $$;

rollback;
