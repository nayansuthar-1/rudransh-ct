-- Seed for test/integration/supabase_repository_test.dart. Run after
-- auth_stub.sql and the migrations on a disposable database; the tests write
-- rows, so reseed a fresh database before each run.

-- PostgREST connects as `authenticator` and switches to anon/authenticated.
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'authenticator') then
    create role authenticator login noinherit;
  end if;
end $$;
grant anon, authenticated to authenticator;

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a001', 'admin@test.local'),
  ('00000000-0000-0000-0000-00000000a002', 'stranger@test.local');
insert into public.profiles (user_id, role, name, email)
values ('00000000-0000-0000-0000-00000000a001', 'owner', 'Integration Admin', 'admin@test.local');

insert into public.yojnas (name, code, contribution_amount, claim_amount) values
  ('सुरक्षा सहयोग योजना', 'SSY', 100, 100000),
  ('परिवार सहयोग योजना', 'PSY', 50, 50000);

insert into public.agents (code, name, phone) values
  ('', 'एजेंट एक', '9800000001'),
  ('', 'एजेंट दो', '9800000002');

-- 2,500 members: every 4th in PSY (625), every 3rd in बाड़मेर (833).
insert into public.members (yojna_id, reg_no, name, primary_phone, agent_id, district, join_date)
select (select id from public.yojnas where code = case when g % 4 = 0 then 'PSY' else 'SSY' end),
       '',
       'सदस्य ' || g,
       (9000000000 + g)::text,
       (select id from public.agents order by code limit 1 offset (g % 2)),
       case when g % 3 = 0 then 'बाड़मेर' else 'जोधपुर' end,
       date '2026-01-01' + (g % 250)
  from generate_series(1, 2500) g;

-- One ₹100 receipt per member, every 10th pending.
insert into public.payments (receipt_no, member_id, yojna_id, amount, agent_id, status, date)
select '', id, yojna_id, 100, agent_id,
       (case when row_number() over (order by reg_no) % 10 = 0 then 'pending' else 'paid' end)::public.payment_status,
       current_date - (row_number() over (order by reg_no) % 40)::int
  from public.members;

-- Five members with a closing, ₹75,000 pending on each claim. A closing no
-- longer closes its member, so they are marked Closed here to keep a Closed
-- set for the status filter tests.
insert into public.closing_cases (member_id, yojna_id, claim_amount, collected_amount, closing_group)
select id, yojna_id, 100000, 25000, 'Group-1'
  from public.members order by reg_no limit 5;
update public.members set status = 'closed'
 where id in (select member_id from public.closing_cases);

-- ---------------------------------------------------------------------------
-- Logins for the Phase 17 access sweep (test/integration/role_api_test.dart)
-- ---------------------------------------------------------------------------
-- One login per role, so the sweep can try every door as every kind of user:
-- both agents (each owning half the members above), one member, and a
-- signed-in user with no profile at all.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000a003', 'agent.one@test.local'),
  ('00000000-0000-0000-0000-00000000a004', 'agent.two@test.local'),
  ('00000000-0000-0000-0000-00000000a005', 'member.one@test.local');

insert into public.profiles (user_id, role, agent_id, name, email)
select '00000000-0000-0000-0000-00000000a003', 'agent', id, 'Agent One',
       'agent.one@test.local'
  from public.agents order by code limit 1;

insert into public.profiles (user_id, role, agent_id, name, email)
select '00000000-0000-0000-0000-00000000a004', 'agent', id, 'Agent Two',
       'agent.two@test.local'
  from public.agents order by code limit 1 offset 1;

-- A member belonging to Agent One, so the sweep can check that Agent Two
-- cannot reach them and that the member sees only themselves.
insert into public.profiles (user_id, role, member_id, name, email)
select '00000000-0000-0000-0000-00000000a005', 'member', m.id, m.name,
       'member.one@test.local'
  from public.members m
  join public.agents a on a.id = m.agent_id
 where a.code = (select min(code) from public.agents)
   and m.status = 'active'
 order by m.reg_no
 limit 1;

-- The receipts above are already `cash` (the column default) and mostly Paid,
-- so both agents have cash in hand and a commission month without any extra
-- setup here.
