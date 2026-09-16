-- Access control: only invited admins can read or change anything, plus an
-- append-only audit trail.

-- ---------------------------------------------------------------------------
-- Admin check
-- ---------------------------------------------------------------------------

create function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins where user_id = (select auth.uid()));
$$;

-- ---------------------------------------------------------------------------
-- Audit log
-- ---------------------------------------------------------------------------

create table public.audit_log (
  id         bigint generated always as identity primary key,
  table_name text not null,
  row_id     uuid,
  action     text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data   jsonb,
  new_data   jsonb,
  user_id    uuid default auth.uid(),
  created_at timestamptz not null default now()
);

create index audit_log_row_idx on public.audit_log (table_name, row_id);
create index audit_log_created_idx on public.audit_log (created_at desc);

-- Personal identifiers are left out of the JSON (IMPLEMENTATION_PLAN §7).
create function public.write_audit_log() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  redact constant text[] := array['aadhaar'];
  o jsonb;
  n jsonb;
begin
  if tg_op <> 'INSERT' then o := to_jsonb(old) - redact; end if;
  if tg_op <> 'DELETE' then n := to_jsonb(new) - redact; end if;
  insert into public.audit_log (table_name, row_id, action, old_data, new_data)
  values (tg_table_name, coalesce((n ->> 'id')::uuid, (o ->> 'id')::uuid), tg_op, o, n);
  return null;
end $$;

do $$
declare t text;
begin
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases'] loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.write_audit_log()',
      t || '_audit', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

-- Defense in depth: the anon role gets nothing, even before RLS is checked.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;
revoke all on all functions in schema public from anon, public;
alter default privileges in schema public revoke all on tables from anon;
alter default privileges in schema public revoke all on functions from anon, public;

grant select, insert, update, delete
  on public.yojnas, public.agents, public.members, public.payments, public.closing_cases
  to authenticated;
grant select on public.admins, public.counters, public.audit_log to authenticated;
-- Supabase's default grants include writes; RLS would block them, but these
-- tables are changed only by triggers and the dashboard.
revoke insert, update, delete, truncate
  on public.admins, public.counters, public.audit_log from authenticated;

-- Numbering and audit helpers run only from triggers.
revoke all on function public.next_number(text) from authenticated;
grant execute on function public.is_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- Row-level security
-- ---------------------------------------------------------------------------

alter table public.admins        enable row level security;
alter table public.counters      enable row level security;
alter table public.audit_log     enable row level security;
alter table public.yojnas        enable row level security;
alter table public.agents        enable row level security;
alter table public.members       enable row level security;
alter table public.payments      enable row level security;
alter table public.closing_cases enable row level security;

do $$
declare t text;
begin
  foreach t in array array['yojnas', 'agents', 'members', 'payments', 'closing_cases'] loop
    execute format(
      'create policy admin_all on public.%I for all to authenticated
         using ((select public.is_admin())) with check ((select public.is_admin()))',
      t);
  end loop;
end $$;

-- Admins are managed from the Supabase dashboard (service role); in the app
-- they can only read the list.
create policy admin_read on public.admins for select to authenticated
  using ((select public.is_admin()));

-- Read-only so the forms can preview the next number.
create policy admin_read on public.counters for select to authenticated
  using ((select public.is_admin()));

create policy admin_read on public.audit_log for select to authenticated
  using ((select public.is_admin()));
