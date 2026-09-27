-- Two more photos on the member form (client request, 27 Sep 2026): the
-- Aadhaar card and the Vaarisdar (nominee). Like the member photo, each is a
-- Cloudinary `https://` URL; the database holds text only.
--
-- The office reads and writes them through the members table. Agents send
-- both with a new member but get neither back: `agent_members` is unchanged,
-- so an agent never sees the Aadhaar card again, as with the number itself.
-- Nor do members or the public lookup.

alter table public.members
  add column if not exists aadhaar_photo_url text not null default '',
  add column if not exists waris_photo_url   text not null default '';

-- Same as 20260929000100_member_contribution.sql, plus the two photos.
create or replace function public.agent_add_member(p_member jsonb) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  a uuid := public.require_agent();
  y uuid := nullif(p_member ->> 'yojna_id', '')::uuid;
  amt numeric := coalesce(nullif(p_member ->> 'contribution_amount', '')::numeric, 0);
  new_id uuid;
begin
  if y is null or not exists (select 1 from public.agent_yojnas() ay where ay.id = y) then
    raise exception 'You cannot enrol members in this Yojna.';
  end if;
  if amt <= 0 then
    raise exception 'Enter the contribution per closing.';
  end if;

  insert into public.members (
    yojna_id, name, father_or_husband_name, jati, gotra, dob,
    waris_name, waris_relation, gender, primary_phone, alt_phone, aadhaar,
    village, tehsil, district, state, pincode, agent_id, join_date, status,
    photo_url, aadhaar_photo_url, waris_photo_url, contribution_amount
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
    'pending',
    trim(coalesce(p_member ->> 'photo_url', '')),
    trim(coalesce(p_member ->> 'aadhaar_photo_url', '')),
    trim(coalesce(p_member ->> 'waris_photo_url', '')),
    amt
  ) returning id into new_id;
  return new_id;
end $$;

-- Same as 20260927000200_member_email.sql; erasing a member now also clears
-- the two new photos. The files themselves stay on Cloudinary until someone
-- deletes them there.
create or replace function public.erase_member_data(p_member_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_reg    text;
begin
  perform public.require_owner();
  if v_reason = '' then
    raise exception 'Give a reason.';
  end if;

  select reg_no into v_reg from public.members where id = p_member_id;
  if not found then
    raise exception 'Member not found.';
  end if;

  -- `aadhaar` stays out of the SET list: the encrypt trigger fires on that
  -- column and its "empty means unchanged" branch would restore the
  -- ciphertext this statement is trying to remove.
  update public.members set
    name                   = 'Erased member',
    father_or_husband_name = '',
    jati                   = '',
    gotra                  = '',
    dob                    = null,
    waris_name             = '',
    waris_relation         = '',
    -- The column demands ten digits, so it cannot simply be emptied.
    primary_phone          = '0000000000',
    alt_phone              = '',
    email                  = '',
    photo_url              = '',
    aadhaar_photo_url      = '',
    waris_photo_url        = '',
    village                = '',
    tehsil                 = '',
    district               = '',
    state                  = '',
    pincode                = '',
    aadhaar_enc            = null,
    aadhaar_last4          = '',
    consent_note           = '',
    status                 = 'inactive',
    review_note            = 'Erased on request: ' || v_reason
  where id = p_member_id;

  update public.profiles set is_active = false where member_id = p_member_id;

  -- Nothing addressed to them should survive either.
  delete from public.lookup_attempts where reg_no = v_reg;
end $$;
