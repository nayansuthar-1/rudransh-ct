-- Release 2, Phase 10 (IMPLEMENTATION_PLAN §11.4): new enum values.
-- Kept in its own migration because Postgres cannot use an enum value in the
-- same transaction that adds it; 20260917000200_roles.sql uses this one.

-- A member added by an agent waits here until an admin approves it.
alter type public.member_status add value if not exists 'pending';
