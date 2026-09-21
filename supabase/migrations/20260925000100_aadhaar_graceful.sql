-- Fix: the encrypt_member_aadhaar trigger raised a hard exception when the
-- Vault key was not configured, blocking member creation entirely. Now it
-- degrades gracefully: the last four digits are kept and the full number is
-- discarded (never stored in plain text), so members can be enrolled even
-- before the key is set up.

create or replace function public.encrypt_member_aadhaar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v text := regexp_replace(coalesce(new.aadhaar, ''), '\D', '', 'g');
  k text;
begin
  -- Whatever arrives, the plain column never survives to disk.
  new.aadhaar := '';

  if v = '' then
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

  -- Try to fetch the encryption key; if it is not set up yet, degrade
  -- gracefully: keep only the last four digits so the member can still
  -- be enrolled. The full number is NOT stored in plain text either way.
  begin
    k := public.aadhaar_key();
  exception when others then
    k := null;
  end;

  if k is not null then
    new.aadhaar_enc := extensions.pgp_sym_encrypt(v, k);
  else
    new.aadhaar_enc := null;
  end if;
  new.aadhaar_last4 := right(v, 4);
  return new;
end $$;
