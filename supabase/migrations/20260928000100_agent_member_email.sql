-- Agents get the office's member menu, minus what stays office-only (client
-- decision, 25 Sep 2026): they may set their own members' email and invite
-- them to the app. Delete, erase, export and the full edit stay with the
-- office.
--
-- `agent_members` now also returns the member's email, so the agent sees and
-- edits it and the invite starts from it. Its return type changes, so it is
-- dropped and made again (as in 20260925000200_member_photo.sql).

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
  closing_group text, review_note text, photo_url text, email text
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
         m.closing_date, m.closing_group, m.review_note, m.photo_url, m.email
    from public.members m
   where m.agent_id = a
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_status is null or m.status = p_status)
   order by m.join_date desc, m.created_at desc;
end $$;

revoke all on function public.agent_members(text, public.member_status)
from public, anon;
grant execute on function public.agent_members(text, public.member_status)
to authenticated;

-- The contact an agent may change now includes the email. It is stored
-- lowercase, which the column insists on; a malformed one is refused by the
-- column's check with the database's own message.
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
    pincode       = trim(coalesce(p_contact ->> 'pincode', pincode)),
    email         = lower(trim(coalesce(p_contact ->> 'email', email)))
  where id = p_member_id and agent_id = a;
  if not found then
    raise exception 'Member not found.';
  end if;
end $$;
