-- The public lookup no longer asks for the registration number (client
-- request, 24 Sep 2026). A member proves who they are with a phone number on
-- their record and the last four digits of their Aadhaar.
--
-- With the registration number gone, the Aadhaar digits stop being optional.
-- Skipping them for a member with none on record — as the old lookup did —
-- would hand that member's standing to anyone who knows the phone number. Such
-- a member now finds nothing and asks the office.
--
-- One phone can hold more than one membership (the same person in two
-- Yojnas), so every match comes back, not just the first.
--
-- The five-try lock moves to the phone number, which is now what is being
-- guessed against.

alter table public.lookup_attempts
  alter column reg_no set default '',
  add column phone text not null default '';

create index lookup_attempts_phone_idx
  on public.lookup_attempts (phone, created_at desc);

-- The parameter changes meaning, and `create or replace` cannot rename it.
drop function public.member_lookup(text, text, text);
drop function public.lookup_locked(text);

-- Five wrong tries for one phone number within 15 minutes and that number is
-- locked for the rest of the window.
create function public.lookup_locked(p_phone text) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) >= 5
    from public.lookup_attempts a
   where a.phone = p_phone
     and not a.succeeded
     and a.created_at > now() - interval '15 minutes';
$$;

-- Phone + the last four Aadhaar digits. Returns every membership that
-- matches, or nothing. Only a summary comes back: no Aadhaar, no address, no
-- agent.
create function public.member_lookup(p_phone text, p_aadhaar4 text)
returns table (
  reg_no text, name text, yojna_name text, status public.member_status,
  join_date date, contribution_amount numeric, dues_count bigint,
  dues_amount numeric
)
language plpgsql security definer set search_path = '' as $$
declare
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_a4    text := regexp_replace(coalesce(p_aadhaar4, ''), '\D', '', 'g');
  v_ids   uuid[];
begin
  if v_phone !~ '^\d{10}$' then
    raise exception 'Enter the 10-digit phone number.';
  end if;
  if v_a4 !~ '^\d{4}$' then
    raise exception 'Enter the last 4 digits of your Aadhaar.';
  end if;
  if public.lookup_locked(v_phone) then
    raise exception 'Too many wrong tries. Try again after 15 minutes.'
      using errcode = 'P0001';
  end if;

  select array_agg(m.id) into v_ids
    from public.members m
   where (m.primary_phone = v_phone or m.alt_phone = v_phone)
     and m.aadhaar_last4 = v_a4;

  -- The lock only looks back 15 minutes; keeping a day is plenty, and it
  -- means no phone number lingers here long after the fact.
  delete from public.lookup_attempts where created_at < now() - interval '1 day';
  insert into public.lookup_attempts (phone, succeeded)
  values (v_phone, v_ids is not null);

  if v_ids is null then
    return;
  end if;

  return query
  select m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount,
         count(d.closing_group) filter (where d.due > 0),
         coalesce(sum(d.due), 0)
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.member_dues d on d.member_id = m.id
   where m.id = any(v_ids)
   group by m.id, m.reg_no, m.name, y.name, m.status, m.join_date,
            y.contribution_amount
   order by m.join_date, m.reg_no;
end $$;

-- Reachable only by the Edge Function, which checks Turnstile first.
revoke execute on function
  public.member_lookup(text, text),
  public.lookup_locked(text)
from public, anon, authenticated;

grant execute on function public.member_lookup(text, text) to service_role;
