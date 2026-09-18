-- Phase 14 (IMPLEMENTATION_PLAN §11): notifications and announcements.
-- Rolled back at the end:
--   psql "$STAGING_DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/notifications_test.sql
-- Any failed check raises an exception and aborts the run.

begin;

-- ---------------------------------------------------------------------------
-- Fixtures (as table owner)
-- ---------------------------------------------------------------------------
--   e001 owner   e002 agent A (Y1)   e003 agent B (Y1)
--
--   N1  agent A, active, Y1
--   N2  agent A, active, Y1   (moved to agent B below)
--   N3  agent B, active, Y1
--   N4  agent A, active, Y2   (a second Yojna, for announcement scoping)
--   ND  agent A, active, Y1   (dies below, making a closing)
insert into auth.users (id, email)
select ('00000000-0000-0000-0000-00000000e0' || lpad(g::text, 2, '0'))::uuid, 'notif' || g || '@test.local'
  from generate_series(1, 3) g;

insert into public.yojnas (id, name, code, contribution_amount, claim_amount, registration_fee) values
  ('00000000-0000-0000-0000-0000000e0001', 'Notif One', 'NOQA', 100, 50000, 50),
  ('00000000-0000-0000-0000-0000000e0002', 'Notif Two', 'NOQB', 200, 90000, 50);

insert into public.agents (id, code, name, yojna_ids) values
  ('00000000-0000-0000-0000-0000000e0011', '', 'Notif Agent A',
   array['00000000-0000-0000-0000-0000000e0001'::uuid, '00000000-0000-0000-0000-0000000e0002'::uuid]),
  ('00000000-0000-0000-0000-0000000e0012', '', 'Notif Agent B',
   array['00000000-0000-0000-0000-0000000e0001'::uuid]);

insert into public.members (id, yojna_id, name, primary_phone, agent_id, join_date, status) values
  ('00000000-0000-0000-0000-0000000e0021', '00000000-0000-0000-0000-0000000e0001', 'Notif N1', '9600000001',
   '00000000-0000-0000-0000-0000000e0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000e0022', '00000000-0000-0000-0000-0000000e0001', 'Notif N2', '9600000002',
   '00000000-0000-0000-0000-0000000e0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000e0023', '00000000-0000-0000-0000-0000000e0001', 'Notif N3', '9600000003',
   '00000000-0000-0000-0000-0000000e0012', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000e0024', '00000000-0000-0000-0000-0000000e0002', 'Notif N4', '9600000004',
   '00000000-0000-0000-0000-0000000e0011', current_date - 400, 'active'),
  ('00000000-0000-0000-0000-0000000e0025', '00000000-0000-0000-0000-0000000e0001', 'Notif ND', '9600000005',
   '00000000-0000-0000-0000-0000000e0011', current_date - 900, 'active');

insert into public.profiles (user_id, role, agent_id) values
  ('00000000-0000-0000-0000-00000000e001', 'owner', null),
  ('00000000-0000-0000-0000-00000000e002', 'agent', '00000000-0000-0000-0000-0000000e0011'),
  ('00000000-0000-0000-0000-00000000e003', 'agent', '00000000-0000-0000-0000-0000000e0012');

-- Two collections by agent A, waiting for approval.
insert into public.payments (id, receipt_no, member_id, yojna_id, amount, status, kind, agent_id) values
  ('00000000-0000-0000-0000-0000000e0031', '', '00000000-0000-0000-0000-0000000e0021',
   '00000000-0000-0000-0000-0000000e0001', 100, 'pending', 'contribution',
   '00000000-0000-0000-0000-0000000e0011'),
  ('00000000-0000-0000-0000-0000000e0032', '', '00000000-0000-0000-0000-0000000e0022',
   '00000000-0000-0000-0000-0000000e0001', 100, 'pending', 'contribution',
   '00000000-0000-0000-0000-0000000e0011');

-- A death agent A reported, still pending.
insert into public.closing_requests (id, member_id, agent_id, date_of_death, status) values
  ('00000000-0000-0000-0000-0000000e0041', '00000000-0000-0000-0000-0000000e0025',
   '00000000-0000-0000-0000-0000000e0011', current_date - 10, 'pending');

-- Nothing has happened yet.
do $$
declare a constant uuid := '00000000-0000-0000-0000-00000000e002';
begin
  assert (select count(*) from public.notifications where user_id = a) = 0,
    'agent A starts with no notifications';
end $$;

-- ---------------------------------------------------------------------------
-- Admin decisions notify the agent who collected
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e001', true);

do $$
begin
  perform public.approve_payment('00000000-0000-0000-0000-0000000e0031');
  perform public.reject_payment('00000000-0000-0000-0000-0000000e0032', 'Amount does not match the receipt');
end $$;

reset role;

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000e002';
  n record;
begin
  assert (select count(*) from public.notifications where user_id = a) = 2,
    'approve and reject each notify once';

  select * into n from public.notifications
   where user_id = a and type = 'payment_approved';
  assert n.title = 'Payment approved', 'approved title: ' || n.title;
  assert n.body like '%Notif N1%', 'approved names the member: ' || n.body;
  assert n.link = '/agent/collections', 'approved links to collections';
  assert n.read_at is null, 'a new notification is unread';

  select * into n from public.notifications
   where user_id = a and type = 'payment_rejected';
  assert n.body like '%Amount does not match the receipt%',
    'rejected carries the reason: ' || n.body;

  -- The other agent hears nothing about A's collections.
  assert (select count(*) from public.notifications
           where user_id = '00000000-0000-0000-0000-00000000e003') = 0,
    'agent B is not told about agent A''s payments';
end $$;

-- Re-saving an approved payment stays quiet.
update public.payments set note = 'touched'
 where id = '00000000-0000-0000-0000-0000000e0031';

do $$
begin
  assert (select count(*) from public.notifications
           where user_id = '00000000-0000-0000-0000-00000000e002') = 2,
    'editing a decided payment does not notify again';
end $$;

-- ---------------------------------------------------------------------------
-- A death report decided, and the closing it creates
-- ---------------------------------------------------------------------------

-- Approving the report opens a closing case; both notify.
insert into public.closing_cases (id, member_id, yojna_id, closing_date, closing_group, claim_amount) values
  ('00000000-0000-0000-0000-0000000e0051', '00000000-0000-0000-0000-0000000e0025',
   '00000000-0000-0000-0000-0000000e0001', current_date - 5, 'N-1', 50000);

update public.closing_requests
   set status = 'approved', closing_case_id = '00000000-0000-0000-0000-0000000e0051'
 where id = '00000000-0000-0000-0000-0000000e0041';

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000e002';
  b constant uuid := '00000000-0000-0000-0000-00000000e003';
  n record;
begin
  select * into n from public.notifications where user_id = a and type = 'closing_approved';
  assert n.body like '%Notif ND%', 'report approval names the member: ' || n.body;

  -- Every agent with an active member in Y1 hears about the new closing.
  assert (select count(*) from public.notifications where user_id = a and type = 'closing_new') = 1,
    'agent A told about the new closing';
  assert (select count(*) from public.notifications where user_id = b and type = 'closing_new') = 1,
    'agent B told about the new closing';
  select * into n from public.notifications where user_id = b and type = 'closing_new';
  assert n.body like '%Notif One%', 'closing notice names the Yojna: ' || n.body;
end $$;

-- ---------------------------------------------------------------------------
-- Overdue dues: one notice per agent per group, not repeated the same day
-- ---------------------------------------------------------------------------

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000e002';
  sent integer;
begin
  -- The closing is 5 days old, so nothing is overdue at 30 days.
  assert public.notify_overdue_dues(30) = 0, 'nothing overdue yet';

  sent := public.notify_overdue_dues(1);
  assert sent >= 1, 'overdue notices sent: ' || sent;
  assert (select count(*) from public.notifications where user_id = a and type = 'dues_overdue') = 1,
    'agent A told once';

  -- Running again the same day adds nothing.
  assert public.notify_overdue_dues(1) = 0, 'a second run the same day is quiet';
  assert (select count(*) from public.notifications where user_id = a and type = 'dues_overdue') = 1,
    'still one overdue notice for agent A';
end $$;

-- ---------------------------------------------------------------------------
-- Moving a member tells both agents
-- ---------------------------------------------------------------------------

update public.members set agent_id = '00000000-0000-0000-0000-0000000e0012'
 where id = '00000000-0000-0000-0000-0000000e0022';

do $$
declare
  a constant uuid := '00000000-0000-0000-0000-00000000e002';
  b constant uuid := '00000000-0000-0000-0000-00000000e003';
begin
  assert (select count(*) from public.notifications
           where user_id = b and type = 'member_assigned' and body like '%Notif N2%') = 1,
    'the new agent is told the member arrived';
  assert (select count(*) from public.notifications
           where user_id = a and type = 'member_removed' and body like '%Notif N2%') = 1,
    'the old agent is told the member left';
end $$;

-- An update that does not change the agent stays quiet.
update public.members set agent_id = '00000000-0000-0000-0000-0000000e0012'
 where id = '00000000-0000-0000-0000-0000000e0022';

do $$
begin
  assert (select count(*) from public.notifications
           where user_id = '00000000-0000-0000-0000-00000000e003' and type = 'member_assigned') = 1,
    'writing the same agent again does not notify';
end $$;

-- ---------------------------------------------------------------------------
-- Reading your own notifications, and nobody else's
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e002', true);

do $$
declare
  first_id bigint;
  before   integer;
begin
  -- The table itself stays out of reach; the function is the way in.
  assert (select count(*) from public.notifications) = 0, 'agent reads notifications directly';

  before := public.my_unread_count();
  assert before > 0, 'agent A has unread notifications';
  assert (select count(*) from public.my_notifications()) = before,
    'every notification is unread so far';

  -- Newest first.
  select id into first_id from public.my_notifications() limit 1;
  assert first_id = (select max(id) from public.my_notifications()), 'newest notification first';

  perform public.mark_notification_read(first_id);
  assert public.my_unread_count() = before - 1, 'marking one read lowers the count';
  assert (select read_at from public.my_notifications() where id = first_id) is not null,
    'the one marked read has a timestamp';

  -- Marking it again changes nothing.
  perform public.mark_notification_read(first_id);
  assert public.my_unread_count() = before - 1, 'marking the same one twice is harmless';

  assert public.mark_all_notifications_read() = before - 1, 'the rest are marked read';
  assert public.my_unread_count() = 0, 'nothing unread afterwards';
end $$;

-- Agent B cannot mark agent A's notification read.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e003', true);

do $$
declare
  a_id bigint;
  b_unread integer;
begin
  b_unread := public.my_unread_count();
  assert b_unread > 0, 'agent B has notifications of their own';
  assert not exists (
    select 1 from public.my_notifications() where type in ('payment_approved', 'payment_rejected')
  ), 'agent B does not see agent A''s payment notices';
end $$;

reset role;

-- The helpers are not app entry points.
do $$
begin
  assert not has_function_privilege('authenticated',
    'public.notify(uuid, text, text, text, text)', 'execute'),
    'notify is callable by a signed-in user';
  assert not has_function_privilege('authenticated',
    'public.notify_overdue_dues(integer)', 'execute'),
    'the overdue sweep is callable by a signed-in user';
  assert has_function_privilege('authenticated',
    'public.my_notifications(integer, integer)', 'execute'),
    'my_notifications is not callable';
end $$;

-- ---------------------------------------------------------------------------
-- Announcements
-- ---------------------------------------------------------------------------

set local role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e001', true);

create temporary table nt (key text primary key, id uuid) on commit drop;
grant all on nt to authenticated;

do $$
begin
  insert into nt values
    ('all', public.post_announcement('Office closed on Monday', 'Diwali holiday.', null)),
    ('y1',  public.post_announcement('Y1 contribution raised', 'From next closing.',
            '00000000-0000-0000-0000-0000000e0001')),
    ('y2',  public.post_announcement('Y2 notice', '', '00000000-0000-0000-0000-0000000e0002'));

  -- A title is required.
  begin
    perform public.post_announcement('   ', 'body', null);
    raise exception 'blank title accepted';
  exception when raise_exception then
    if sqlerrm not like 'Give the announcement%' then raise; end if;
  end;

  -- An admin sees all three.
  assert (select count(*) from public.my_announcements()
           where id in (select id from nt)) = 3, 'the admin sees every announcement';
end $$;

-- Agent A has members in Y1 and Y2, so sees all three.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e002', true);

do $$
begin
  assert (select count(*) from public.my_announcements()
           where id in (select id from nt)) = 3,
    'agent A sees the trust-wide notice and both Yojnas';

  -- Posting is an admin's job.
  begin
    perform public.post_announcement('Agent notice', '', null);
    raise exception 'an agent posted an announcement';
  exception when insufficient_privilege then
    null;
  end;
end $$;

-- Agent B only has members in Y1.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e003', true);

do $$
begin
  assert (select count(*) from public.my_announcements()
           where id in (select id from nt)) = 2,
    'agent B sees the trust-wide notice and Y1 only';
  assert not exists (
    select 1 from public.my_announcements()
     where id = (select id from nt where key = 'y2')
  ), 'agent B does not see the Y2 announcement';
end $$;

-- Deleting is an admin's job too.
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000e001', true);

do $$
begin
  perform public.delete_announcement((select id from nt where key = 'y2'));
  assert (select count(*) from public.my_announcements()
           where id in (select id from nt)) = 2, 'the deleted announcement is gone';

  begin
    perform public.delete_announcement((select id from nt where key = 'y2'));
    raise exception 'deleting twice succeeded';
  exception when raise_exception then
    if sqlerrm not like 'That announcement is already%' then raise; end if;
  end;
end $$;

reset role;

do $$ begin raise notice 'notification and announcement checks passed'; end $$;

rollback;
