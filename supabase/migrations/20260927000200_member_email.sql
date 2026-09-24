-- Members get an email address, for signing in without an invite (client
-- request, 24 Sep 2026). A member whose email is on their record asks for a
-- sign-in code on the login page; the `member_sign_in` Edge Function makes
-- their login first. Optional: most members have no email.

alter table public.members
  add column if not exists email text not null default ''
    check (email = '' or (email = lower(email)
           and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'));

-- Stored lowercase, so sign-in matches exactly.
create index if not exists members_email_idx
  on public.members (email) where email <> '';

-- Erasing a member (DPDP request) now also clears the two fields added since
-- `20260924000200_privacy.sql` — email and photo — and switches off any
-- member login, so an erased member cannot sign in to what is left.
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
