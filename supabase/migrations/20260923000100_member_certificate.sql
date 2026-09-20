-- Membership certificate (docs/MEMBERSHIP_CERTIFICATE_PLAN.md).
--
-- The printed certificate asks for two things the member record never held:
-- date of birth (`जन्म दि`) and state (`राज्य`). Both are optional — existing
-- members predate them, and the certificate prints a blank dotted line where a
-- value is missing.

-- ---------------------------------------------------------------------------
-- Columns
-- ---------------------------------------------------------------------------

alter table public.members
  add column dob   date,
  add column state text not null default '';

-- ---------------------------------------------------------------------------
-- Agent functions
-- ---------------------------------------------------------------------------

-- `agent_members` gains two output columns, so its return type changes and the
-- old function has to go first. Recreating it drops its grants with it, so they
-- are given again at the bottom.
drop function if exists public.agent_members(text, public.member_status);

create function public.agent_members(
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
         m.primary_phone, m.alt_phone, right(m.aadhaar, 4), m.village, m.tehsil,
         m.district, m.state, m.pincode, m.join_date, m.status,
         m.closing_date, m.closing_group, m.review_note
    from public.members m
   where m.agent_id = a
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_status is null or m.status = p_status)
   order by m.join_date desc, m.created_at desc;
end $$;

-- Sign-up now carries the two certificate fields. Both stay optional: an agent
-- who does not know the date of birth leaves it out.
create or replace function public.agent_add_member(p_member jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  y uuid := nullif(p_member ->> 'yojna_id', '')::uuid;
  new_id uuid;
begin
  if y is null or not exists (select 1 from public.agent_yojnas() ay where ay.id = y) then
    raise exception 'You cannot enrol members in this Yojna.';
  end if;

  insert into public.members (
    yojna_id, name, father_or_husband_name, jati, gotra, dob,
    waris_name, waris_relation, gender, primary_phone, alt_phone, aadhaar,
    village, tehsil, district, state, pincode, agent_id, join_date, status
  ) values (
    y,
    trim(coalesce(p_member ->> 'name', '')),
    trim(coalesce(p_member ->> 'father_or_husband_name', '')),
    trim(coalesce(p_member ->> 'jati', '')),
    trim(coalesce(p_member ->> 'gotra', '')),
    nullif(p_member ->> 'dob', '')::date,
    trim(coalesce(p_member ->> 'waris_name', '')),
    trim(coalesce(p_member ->> 'waris_relation', '')),
    coalesce(nullif(p_member ->> 'gender', '')::public.gender, 'male'),
    trim(p_member ->> 'primary_phone'),
    trim(coalesce(p_member ->> 'alt_phone', '')),
    trim(coalesce(p_member ->> 'aadhaar', '')),
    trim(coalesce(p_member ->> 'village', '')),
    trim(coalesce(p_member ->> 'tehsil', '')),
    trim(coalesce(p_member ->> 'district', '')),
    trim(coalesce(p_member ->> 'state', '')),
    trim(coalesce(p_member ->> 'pincode', '')),
    a,
    coalesce(nullif(p_member ->> 'join_date', '')::date, public.today_ist()),
    'pending'
  ) returning id into new_id;
  return new_id;
end $$;

-- State sits with the rest of the address, so an agent may correct it. Date of
-- birth stays with the office: it is identity, like the name and the nominee.
create or replace function public.agent_update_contact(p_member_id uuid, p_contact jsonb)
returns void
language plpgsql security definer set search_path = '' as $$
declare a uuid := public.require_agent();
begin
  update public.members set
    primary_phone = trim(coalesce(p_contact ->> 'primary_phone', primary_phone)),
    alt_phone     = trim(coalesce(p_contact ->> 'alt_phone', alt_phone)),
    village       = trim(coalesce(p_contact ->> 'village', village)),
    tehsil        = trim(coalesce(p_contact ->> 'tehsil', tehsil)),
    district      = trim(coalesce(p_contact ->> 'district', district)),
    state         = trim(coalesce(p_contact ->> 'state', state)),
    pincode       = trim(coalesce(p_contact ->> 'pincode', pincode))
  where id = p_member_id and agent_id = a;
  if not found then
    raise exception 'Member not found.';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- Grants (only agent_members needs them again; the other two were replaced)
-- ---------------------------------------------------------------------------

revoke all on function public.agent_members(text, public.member_status)
from public, anon;

grant execute on function public.agent_members(text, public.member_status)
to authenticated;
