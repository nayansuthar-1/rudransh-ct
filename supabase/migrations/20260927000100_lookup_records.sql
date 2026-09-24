-- The public lookup hands a member their own papers: approved receipts to
-- print, and the fields their membership certificate prints (client request,
-- 24 Sep 2026). Most members have no email and so no portal login; this is
-- how they get a copy.
--
-- Everything stays behind the same door as before: phone + last four Aadhaar
-- digits, Cloudflare Turnstile in the Edge Function, and the five-try lock per
-- phone. What comes back is what the certificate itself prints — name, father,
-- gotra, jati, date of birth, village, district, state, nominee, photo — plus
-- receipts. Never the Aadhaar number, never another member.
--
-- `member_lookup` gains one output column, `details` (jsonb), so it has to be
-- dropped and made again; its grants go with it and are given back below.

drop function public.member_lookup(text, text);

create function public.member_lookup(p_phone text, p_aadhaar4 text)
returns table (
  reg_no text, name text, yojna_name text, status public.member_status,
  join_date date, contribution_amount numeric, dues_count bigint,
  dues_amount numeric, details jsonb
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

  delete from public.lookup_attempts where created_at < now() - interval '1 day';
  insert into public.lookup_attempts (phone, succeeded)
  values (v_phone, v_ids is not null);

  if v_ids is null then
    return;
  end if;

  return query
  select m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount,
         count(d.closing_group) filter (where d.due > 0),
         coalesce(sum(d.due), 0),
         jsonb_build_object(
           'certificate', jsonb_build_object(
             'father_or_husband_name', m.father_or_husband_name,
             'jati', m.jati,
             'gotra', m.gotra,
             'dob', m.dob,
             'waris_name', m.waris_name,
             'waris_relation', m.waris_relation,
             'primary_phone', m.primary_phone,
             'village', m.village,
             'tehsil', m.tehsil,
             'district', m.district,
             'state', m.state,
             'pincode', m.pincode,
             'photo_url', m.photo_url,
             'yojna_description', y.description,
             'yojna_start_date', y.start_date,
             'agent_name', coalesce(a.name, '')
           ),
           -- Approved, not cancelled: the receipts that count, newest first.
           'receipts', coalesce((
             select jsonb_agg(jsonb_build_object(
                      'receipt_no', p.receipt_no,
                      'date', p.date,
                      'amount', p.amount,
                      'kind', p.kind,
                      'mode', p.mode,
                      'reference', p.reference,
                      'closing_group', coalesce(c.closing_group, '')
                    ) order by p.date desc, p.receipt_no desc)
               from public.payments p
               left join public.closing_cases c on c.id = p.closing_case_id
              where p.member_id = m.id
                and p.status = 'paid'
                and p.cancelled_at is null
           ), '[]'::jsonb)
         )
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.agents a on a.id = m.agent_id
    left join public.member_dues d on d.member_id = m.id
   where m.id = any(v_ids)
   group by m.id, y.id, a.id
   order by m.join_date, m.reg_no;
end $$;

revoke execute on function public.member_lookup(text, text)
from public, anon, authenticated;

grant execute on function public.member_lookup(text, text) to service_role;
