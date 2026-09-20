-- IMPLEMENTATION_PLAN §7: the full Aadhaar number is encrypted at rest.
--
-- Until now `members.aadhaar` held all twelve digits in plain text. Anyone with
-- a database dump, a leaked backup or the service role key could read every
-- member's Aadhaar. §7 asks for the number to be encrypted and readable only by
-- an owner; §11.3 says staff may *change* it but not see it.
--
-- **Why pgcrypto and not pgsodium.** Supabase documents pgsodium's Transparent
-- Column Encryption but explicitly does not recommend it, and the extension is
-- in a deprecation cycle. Vault is unaffected and keeps its API. So: pgcrypto
-- does the encryption, Vault holds the key.
--
-- **How it fits together.**
--   * `aadhaar` stays as the *input* column, so every existing write path keeps
--     working unchanged. A trigger encrypts whatever is written and blanks the
--     column, so the plain number is never stored.
--   * `aadhaar_enc` holds the ciphertext; `aadhaar_last4` holds the four digits
--     the lookup page and the masked display already used.
--   * Only `member_aadhaar()` decrypts, and only for an owner.
--
-- **The key** lives in Vault under the name `aadhaar_key`; `docs/RUNBOOK.md` §6
-- has the one-time setup. Without it the database refuses to store an Aadhaar
-- rather than storing it in the clear — a member simply has no Aadhaar on
-- record, which §7 already allows. Everything else keeps working.

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.members
  add column aadhaar_enc   bytea,
  add column aadhaar_last4 text not null default ''
    check (aadhaar_last4 = '' or aadhaar_last4 ~ '^\d{4}$');

comment on column public.members.aadhaar is
  'Input only, never stored: a trigger encrypts it into aadhaar_enc and blanks '
  'this column. Always empty at rest. Read the number with member_aadhaar().';

-- ---------------------------------------------------------------------------
-- The key
-- ---------------------------------------------------------------------------

-- Read from Vault on every call rather than cached, so rotating the secret
-- takes effect immediately. Nobody may call this directly.
create function public.aadhaar_key() returns text
language plpgsql stable security definer set search_path = '' as $$
declare k text;
begin
  select s.decrypted_secret into k
    from vault.decrypted_secrets s
   where s.name = 'aadhaar_key';
  if coalesce(k, '') = '' then
    raise exception
      'The Aadhaar encryption key is not set up on this project, so the number '
      'cannot be stored. See docs/RUNBOOK.md section 6.'
      using errcode = 'P0001';
  end if;
  return k;
end $$;

-- ---------------------------------------------------------------------------
-- Encrypt on the way in
-- ---------------------------------------------------------------------------

create function public.encrypt_member_aadhaar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v text := regexp_replace(coalesce(new.aadhaar, ''), '\D', '', 'g');
begin
  -- Whatever arrives, the plain column never survives to disk.
  new.aadhaar := '';

  if v = '' then
    -- An empty box means "leave it alone" on an edit, so a staff member saving
    -- a member's phone number does not wipe the Aadhaar they cannot see.
    -- Clearing it is deliberate, through clear_member_aadhaar().
    if tg_op = 'UPDATE' then
      new.aadhaar_enc   := old.aadhaar_enc;
      new.aadhaar_last4 := old.aadhaar_last4;
    else
      new.aadhaar_enc   := null;
      new.aadhaar_last4 := '';
    end if;
    return new;
  end if;

  if v !~ '^\d{12}$' then
    raise exception 'Aadhaar number must be 12 digits.';
  end if;

  new.aadhaar_enc   := extensions.pgp_sym_encrypt(v, public.aadhaar_key());
  new.aadhaar_last4 := right(v, 4);
  return new;
end $$;

create trigger members_encrypt_aadhaar
  before insert or update of aadhaar on public.members
  for each row execute function public.encrypt_member_aadhaar();

-- ---------------------------------------------------------------------------
-- Read it back
-- ---------------------------------------------------------------------------

-- Owner only (§11.3: staff see a masked number). Returns '' when the member has
-- no Aadhaar on record, which is allowed.
create function public.member_aadhaar(p_member_id uuid) returns text
language plpgsql stable security definer set search_path = '' as $$
declare v bytea;
begin
  perform public.require_owner();
  select m.aadhaar_enc into v from public.members m where m.id = p_member_id;
  if not found then
    raise exception 'Member not found.';
  end if;
  if v is null then
    return '';
  end if;
  return extensions.pgp_sym_decrypt(v, public.aadhaar_key());
end $$;

-- Removing a number is an explicit act, not a side effect of saving a form.
create function public.clear_member_aadhaar(p_member_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_owner();
  -- Deliberately leaves `aadhaar` out of the SET list. The trigger fires only
  -- `of aadhaar`, and its "empty means unchanged" branch would put the old
  -- ciphertext straight back. The column is already empty at rest anyway.
  update public.members
     set aadhaar_enc = null, aadhaar_last4 = ''
   where id = p_member_id;
  if not found then
    raise exception 'Member not found.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Move what is already there
-- ---------------------------------------------------------------------------

-- Existing rows hold plain numbers. Encrypt them if the key is configured;
-- otherwise keep the last four and drop the rest, because leaving twelve plain
-- digits behind would defeat the point of this migration. Either way no plain
-- Aadhaar survives this statement.
do $$
declare
  has_key boolean := false;
  n       integer;
begin
  begin
    perform public.aadhaar_key();
    has_key := true;
  exception when others then
    has_key := false;
  end;

  -- The trigger has to stand aside here. It fires on `aadhaar`, and blanking
  -- that column is exactly what this statement does — so its "empty means
  -- unchanged" branch would copy the old (still empty) ciphertext back over
  -- the value just computed, quietly undoing the whole migration.
  execute 'alter table public.members disable trigger members_encrypt_aadhaar';

  if has_key then
    update public.members
       set aadhaar_enc = extensions.pgp_sym_encrypt(aadhaar, public.aadhaar_key()),
           aadhaar_last4 = right(aadhaar, 4),
           aadhaar = ''
     where aadhaar <> '';
    get diagnostics n = row_count;
    raise notice 'Aadhaar encrypted for % member(s).', n;
  else
    update public.members
       set aadhaar_last4 = right(aadhaar, 4),
           aadhaar = ''
     where aadhaar <> '';
    get diagnostics n = row_count;
    if n > 0 then
      raise warning
        'No Aadhaar key configured: kept only the last 4 digits for % member(s). '
        'The full numbers are gone. Set the key before importing them again '
        '(docs/RUNBOOK.md section 6).', n;
    end if;
  end if;

  execute 'alter table public.members enable trigger members_encrypt_aadhaar';
end $$;

-- ---------------------------------------------------------------------------
-- Everything that used to read the plain column
-- ---------------------------------------------------------------------------

-- The audit log already dropped `aadhaar`; the ciphertext must go too, or every
-- edit would copy it into audit_log where the redaction was meant to stop it.
create or replace function public.write_audit_log() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  redact constant text[] := array['aadhaar', 'aadhaar_enc', 'aadhaar_last4'];
  o jsonb;
  n jsonb;
begin
  if tg_op <> 'INSERT' then o := to_jsonb(old) - redact; end if;
  if tg_op <> 'DELETE' then n := to_jsonb(new) - redact; end if;
  insert into public.audit_log (table_name, row_id, action, old_data, new_data)
  values (tg_table_name,
          coalesce(n ->> 'id', o ->> 'id', n ->> 'user_id', o ->> 'user_id')::uuid,
          tg_op, o, n);
  return null;
end $$;

-- Agents saw `right(aadhaar, 4)`; that column is empty now, so read the stored
-- four digits instead. Same shape, same masking promise.
create or replace function public.agent_members(
  p_query  text default null,
  p_status public.member_status default null
)
returns table (
  id uuid, yojna_id uuid, reg_no text, name text, father_or_husband_name text,
  jati text, gotra text, dob date, waris_name text, waris_relation text,
  gender public.gender, primary_phone text, alt_phone text, aadhaar_last4 text,
  village text, tehsil text, district text, state text, pincode text,
  join_date date, status public.member_status, closing_date date,
  closing_group text, review_note text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select m.id, m.yojna_id, m.reg_no, m.name, m.father_or_husband_name,
         m.jati, m.gotra, m.dob, m.waris_name, m.waris_relation, m.gender,
         m.primary_phone, m.alt_phone, m.aadhaar_last4, m.village, m.tehsil,
         m.district, m.state, m.pincode, m.join_date, m.status,
         m.closing_date, m.closing_group, m.review_note
    from public.members m
   where m.agent_id = a
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_status is null or m.status = p_status)
   order by m.join_date desc, m.created_at desc;
end $$;

-- The public lookup checks the last four digits, which are still in the clear
-- on purpose: it is the weakest of the three answers a caller must already get
-- right, and it never leaves the Edge Function as data.
create or replace function public.member_lookup(
  p_reg_no text, p_phone text, p_aadhaar4 text
)
returns table (
  reg_no text, name text, yojna_name text, status public.member_status,
  join_date date, contribution_amount numeric, dues_count bigint,
  dues_amount numeric
)
language plpgsql security definer set search_path = '' as $$
declare
  v_reg   text := upper(trim(coalesce(p_reg_no, '')));
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_a4    text := regexp_replace(coalesce(p_aadhaar4, ''), '\D', '', 'g');
  v_id    uuid;
begin
  if v_reg = '' or v_phone = '' then
    raise exception 'Enter the registration number and phone number.';
  end if;
  if public.lookup_locked(v_reg) then
    raise exception 'Too many wrong tries. Try again after 15 minutes.'
      using errcode = 'P0001';
  end if;

  select m.id into v_id
    from public.members m
   where m.reg_no = v_reg
     and (m.primary_phone = v_phone or m.alt_phone = v_phone)
     and (m.aadhaar_last4 = '' or m.aadhaar_last4 = v_a4);

  insert into public.lookup_attempts (reg_no, succeeded)
  values (v_reg, v_id is not null);

  if v_id is null then
    return;
  end if;

  return query
  select m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount,
         count(d.closing_group) filter (where d.due > 0),
         coalesce(sum(d.due), 0)
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.member_dues d on d.member_id = m.id
   where m.id = v_id
   group by m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount;
end $$;

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- The key and the trigger are internal; nothing outside this file calls them.
revoke all on function
  public.aadhaar_key(),
  public.encrypt_member_aadhaar()
from public, anon, authenticated;

revoke all on function
  public.member_aadhaar(uuid),
  public.clear_member_aadhaar(uuid)
from public, anon;

grant execute on function
  public.member_aadhaar(uuid),
  public.clear_member_aadhaar(uuid)
to authenticated;
