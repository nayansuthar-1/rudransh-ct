-- Minimal stand-in for what a Supabase project provides, so migrations and
-- database_test.sql can run on plain Postgres (CI, or a local cluster when
-- Docker is unavailable). Never run this against a real Supabase project.

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then
    create role service_role nologin bypassrls;
  end if;
end $$;

create schema auth;
create schema extensions;

create table auth.users (
  id    uuid primary key default gen_random_uuid(),
  email text
);

-- Same lookup order as Supabase: legacy per-claim setting, then the claims JSON
-- that PostgREST sets for each request.
create function auth.uid() returns uuid language sql stable as $$
  select coalesce(
    nullif(current_setting('request.jwt.claim.sub', true), ''),
    nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'
  )::uuid
$$;

-- Stand-in for Supabase Vault, which holds the Aadhaar encryption key
-- (20260924000100_aadhaar_encryption.sql). The real thing decrypts on read; a
-- plain table is enough here, and the test key never leaves this database.
create schema vault;

create table vault.decrypted_secrets (
  name             text primary key,
  decrypted_secret text not null
);

insert into vault.decrypted_secrets (name, decrypted_secret)
values ('aadhaar_key', 'ci-only-aadhaar-key-not-a-real-secret');

grant usage on schema auth, public, extensions to anon, authenticated, service_role;
grant execute on function auth.uid() to anon, authenticated;

-- Supabase's default grants; the migrations must revoke what anon should not have.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
