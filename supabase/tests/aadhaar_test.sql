-- IMPLEMENTATION_PLAN §7: the Aadhaar number is encrypted at rest and only an
-- owner can read it back. Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/aadhaar_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   b001 owner   b002 staff   b003 agent   b004 member
--   M1 has an Aadhaar, M2 has none.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000b001', 'aad.owner@test.local'),
  ('00000000-0000-0000-0000-00000000b002', 'aad.staff@test.local'),
  ('00000000-0000-0000-0000-00000000b003', 'aad.agent@test.local'),
  ('00000000-0000-0000-0000-00000000b004', 'aad.member@test.local');

insert into public.yojnas (id, name, code, contribution_amount, claim_amount)
values ('00000000-0000-0000-0000-0000000b0001', 'Aadhaar One', 'AADQ', 100, 50000);

insert into public.agents (id, code, name)
values ('00000000-0000-0000-0000-0000000b0011', '', 'Aadhaar Agent');

insert into public.members
  (id, yojna_id, reg_no, name, primary_phone, agent_id, aadhaar) values
  ('00000000-0000-0000-0000-0000000b0021', '00000000-0000-0000-0000-0000000b0001',
   '', 'Aadhaar M1', '9500000021', '00000000-0000-0000-0000-0000000b0011', '123456789012'),
  ('00000000-0000-0000-0000-0000000b0022', '00000000-0000-0000-0000-0000000b0001',
   '', 'Aadhaar M2', '9500000022', '00000000-0000-0000-0000-0000000b0011', '');

-- Contribution is per member (20260929000100): each pays their Yojna's amount.
update public.members m set contribution_amount = y.contribution_amount
  from public.yojnas y where y.id = m.yojna_id;

insert into public.profiles (user_id, role, agent_id, member_id) values
  ('00000000-0000-0000-0000-00000000b001', 'owner',  null, null),
  ('00000000-0000-0000-0000-00000000b002', 'staff',  null, null),
  ('00000000-0000-0000-0000-00000000b003', 'agent', '00000000-0000-0000-0000-0000000b0011', null),
  ('00000000-0000-0000-0000-00000000b004', 'member', null, '00000000-0000-0000-0000-0000000b0021');

-- ---------------------------------------------------------------------------
-- What actually sits on disk
-- ---------------------------------------------------------------------------
do $$
declare m record;
begin
  select * into m from public.members
   where id = '00000000-0000-0000-0000-0000000b0021';

  assert m.aadhaar = '', 'the plain column is empty at rest';
  assert m.aadhaar_enc is not null, 'the ciphertext is stored';
  assert m.aadhaar_last4 = '9012', format('last4 is %s', m.aadhaar_last4);
  -- The whole point: the digits must not be recoverable by reading the row.
  assert position('123456789012' in encode(m.aadhaar_enc, 'escape')) = 0,
    'the plain number is inside the ciphertext';
  assert length(m.aadhaar_enc) > 20, 'the ciphertext looks too short to be real';

  -- A member with no Aadhaar keeps nothing at all.
  select * into m from public.members
   where id = '00000000-0000-0000-0000-0000000b0022';
  assert m.aadhaar_enc is null, 'no ciphertext for a member without an Aadhaar';
  assert m.aadhaar_last4 = '', 'no last4 either';

  raise notice 'storage checks passed';
end $$;

-- Twelve digits or nothing.
do $$
begin
  begin
    insert into public.members (yojna_id, reg_no, name, primary_phone, aadhaar)
    values ('00000000-0000-0000-0000-0000000b0001', '', 'Bad', '9500000099', '12345');
    raise exception 'a short Aadhaar was accepted';
  exception when raise_exception then
    if sqlerrm not like 'Aadhaar number must be 12 digits%' then raise; end if;
  end;
  raise notice 'validation checks passed';
end $$;

set local role authenticated;

-- ---------------------------------------------------------------------------
-- Owner: the only role that sees the number
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b001', true);

do $$
declare m1 constant uuid := '00000000-0000-0000-0000-0000000b0021';
begin
  assert public.member_aadhaar(m1) = '123456789012',
    'an owner reads the number back exactly';
  assert public.member_aadhaar('00000000-0000-0000-0000-0000000b0022') = '',
    'a member without an Aadhaar returns empty, not an error';

  begin
    perform public.member_aadhaar('00000000-0000-0000-0000-00000000dead');
    raise exception 'an unknown member did not raise';
  exception when raise_exception then
    if sqlerrm not like 'Member not found%' then raise; end if;
  end;
  raise notice 'owner checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Staff: may change it, may not see it (§11.3)
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b002', true);

do $$
declare m1 constant uuid := '00000000-0000-0000-0000-0000000b0021';
begin
  begin
    perform public.member_aadhaar(m1);
    raise exception 'staff read the Aadhaar';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.clear_member_aadhaar(m1);
    raise exception 'staff cleared the Aadhaar';
  exception when insufficient_privilege then null;
  end;

  -- Saving an unrelated field must not wipe a number staff cannot see.
  update public.members set primary_phone = '9500000031' where id = m1;
  assert (select aadhaar_last4 from public.members where id = m1) = '9012',
    'an ordinary edit left the Aadhaar alone';
  assert (select aadhaar_enc from public.members where id = m1) is not null,
    'and kept the ciphertext';

  -- Staff may replace it; it is encrypted the same way.
  update public.members set aadhaar = '999988887777' where id = m1;
  assert (select aadhaar_last4 from public.members where id = m1) = '7777',
    'staff replaced the number';
  assert (select aadhaar from public.members where id = m1) = '',
    'and the plain column is still empty';

  raise notice 'staff checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Agent: four digits, never more
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b003', true);

do $$
declare r record;
begin
  select * into r from public.agent_members()
   where id = '00000000-0000-0000-0000-0000000b0021';
  assert r.aadhaar_last4 = '7777', format('agent sees %s', r.aadhaar_last4);

  begin
    perform public.member_aadhaar('00000000-0000-0000-0000-0000000b0021');
    raise exception 'an agent read the Aadhaar';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.aadhaar_key();
    raise exception 'an agent read the key';
  exception when insufficient_privilege then null;
  end;
  raise notice 'agent checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Member and anon
-- ---------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b004', true);

do $$
begin
  begin
    perform public.member_aadhaar('00000000-0000-0000-0000-0000000b0021');
    raise exception 'a member read their own Aadhaar';
  exception when insufficient_privilege then null;
  end;
  raise notice 'member checks passed';
end $$;

reset role;
set local role anon;
select set_config('request.jwt.claim.sub', '', true);

do $$
begin
  begin
    perform public.member_aadhaar('00000000-0000-0000-0000-0000000b0021');
    raise exception 'anon read an Aadhaar';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.aadhaar_key();
    raise exception 'anon read the key';
  exception when insufficient_privilege then null;
  end;
  raise notice 'anon checks passed';
end $$;

reset role;

-- ---------------------------------------------------------------------------
-- The public lookup still works off the last four digits
-- ---------------------------------------------------------------------------
do $$
declare n integer;
begin
  update public.members set status = 'active'
   where id in ('00000000-0000-0000-0000-0000000b0021',
                '00000000-0000-0000-0000-0000000b0022');

  select count(*) into n from public.member_lookup('9500000031', '7777');
  assert n = 1, 'the right last four digits find the member';

  select count(*) into n from public.member_lookup('9500000031', '0000');
  assert n = 0, 'the wrong last four digits find nothing';

  -- A member whose Aadhaar was never recorded has nothing to match: the
  -- phone alone does not find them.
  select count(*) into n from public.member_lookup('9500000022', '1234');
  assert n = 0, 'a member with no Aadhaar is not found on the phone alone';
  raise notice 'lookup checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Nothing leaks into the audit log
-- ---------------------------------------------------------------------------
do $$
declare bad integer;
begin
  select count(*) into bad from public.audit_log
   where table_name = 'members'
     and (old_data ? 'aadhaar' or new_data ? 'aadhaar'
       or old_data ? 'aadhaar_enc' or new_data ? 'aadhaar_enc'
       or old_data ? 'aadhaar_last4' or new_data ? 'aadhaar_last4');
  assert bad = 0, format('% audit rows carry Aadhaar', bad);
  raise notice 'audit checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Owners can remove a number outright
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b001', true);

do $$
declare m1 constant uuid := '00000000-0000-0000-0000-0000000b0021';
begin
  perform public.clear_member_aadhaar(m1);
  assert public.member_aadhaar(m1) = '', 'the number is gone';
  assert (select aadhaar_last4 from public.members where id = m1) = '',
    'and so are the last four digits';
  raise notice 'clear checks passed';
end $$;

-- ---------------------------------------------------------------------------
-- Consent, export and erasure (20260924000200_privacy.sql)
-- ---------------------------------------------------------------------------
set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b001', true);

do $$
declare
  m2 constant uuid := '00000000-0000-0000-0000-0000000b0022';
  doc jsonb;
begin
  -- Give M2 an Aadhaar and consent so the export has something to carry.
  update public.members
     set aadhaar = '555566667777', consent_at = now(), consent_note = 'Signed form'
   where id = m2;

  doc := public.export_member_data(m2);
  assert doc -> 'member' ->> 'name' = 'Aadhaar M2', 'the export names the member';
  assert doc -> 'member' ->> 'aadhaar' = '555566667777',
    'the export carries the decrypted number';
  assert not (doc -> 'member' ? 'aadhaar_enc'), 'no ciphertext in the export';
  assert not (doc -> 'member' ? 'search_text'), 'no search index in the export';
  assert jsonb_typeof(doc -> 'payments') = 'array', 'payments are a list';
  assert doc -> 'yojna' ->> 'code' = 'AADQ', 'the scheme is named';
  raise notice 'export checks passed';
end $$;

do $$
declare
  m2 constant uuid := '00000000-0000-0000-0000-0000000b0022';
  m  record;
begin
  begin
    perform public.erase_member_data(m2, '  ');
    raise exception 'erased without a reason';
  exception when raise_exception then
    if sqlerrm not like 'Give a reason%' then raise; end if;
  end;

  perform public.erase_member_data(m2, 'Member asked');

  select * into m from public.members where id = m2;
  assert m.name = 'Erased member', format('name is %s', m.name);
  assert m.aadhaar_enc is null, 'the Aadhaar is gone';
  assert m.aadhaar_last4 = '', 'and so are the last four digits';
  assert m.primary_phone = '0000000000', 'the phone is blanked';
  assert m.waris_name = '', 'the nominee is gone';
  assert m.status = 'inactive', 'the membership is closed off';
  assert m.review_note like 'Erased on request:%', 'the reason is recorded';
  assert public.member_aadhaar(m2) = '', 'nothing left to decrypt';
  raise notice 'erasure checks passed';
end $$;

-- Staff and agents may do neither.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000b002', true);
do $$
begin
  begin
    perform public.export_member_data('00000000-0000-0000-0000-0000000b0021');
    raise exception 'staff exported a member';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.erase_member_data('00000000-0000-0000-0000-0000000b0021', 'x');
    raise exception 'staff erased a member';
  exception when insufficient_privilege then null;
  end;
  raise notice 'privacy access checks passed';
end $$;

reset role;

rollback;
