-- Clears every business record from a Supabase project, so manual testing
-- starts from an empty panel.
--
-- DESTRUCTIVE AND NOT REVERSIBLE. Meant for staging. Do not run it against
-- production without a backup you have already restored once (docs/RUNBOOK.md §5).
--
--   psql "<session-pooler URL>" -v ON_ERROR_STOP=1 -f scripts/reset_data.sql
--
-- or paste it into the Supabase SQL Editor, which runs as `postgres` and so
-- gets past row-level security and the append-only audit rules.
--
-- Kept: the schema, functions, access rules, and your admin logins
-- (`auth.users` and the owner/staff rows in `public.profiles`).
--
-- Removed along with the records: the profile of any agent or member who had
-- been invited, because `profiles.agent_id` / `member_id` cascade on delete.
-- Their `auth.users` row survives and can no longer sign in; delete it in
-- Dashboard → Authentication → Users, or just invite them again after you
-- recreate the agent.
--
-- Deletes are used rather than `truncate ... cascade`: truncating `agents`
-- would take `public.profiles` with it and wipe every login, including yours.

begin;

-- Children first, so nothing is blocked by an `on delete restrict`.
delete from public.notifications;
delete from public.announcements;
delete from public.change_requests;
delete from public.closing_requests;
delete from public.commission_payouts;
delete from public.cash_handovers;
delete from public.payments;
delete from public.closing_cases;
delete from public.members;   -- cascades to agent/member profiles
delete from public.agents;
delete from public.yojnas;

-- Registration numbers, receipt numbers and agent codes are handed out from
-- here. Without this the first member you add continues the old sequence
-- (SSY-2026-0149) instead of starting at 0001.
delete from public.counters;

-- Last: the deletes above fire the audit triggers.
delete from public.lookup_attempts;
delete from public.audit_log;

commit;

-- Expect zeros across the board, and your admin logins still listed.
select
  (select count(*) from public.yojnas)        as yojnas,
  (select count(*) from public.agents)        as agents,
  (select count(*) from public.members)       as members,
  (select count(*) from public.payments)      as payments,
  (select count(*) from public.closing_cases) as closing_cases,
  (select count(*) from public.counters)      as counters,
  (select count(*) from public.audit_log)     as audit_log;

select name, email, role, is_active from public.profiles order by role, name;
