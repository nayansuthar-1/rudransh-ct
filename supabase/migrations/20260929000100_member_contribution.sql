-- The सहयोग राशि is set per member, not per Yojna (client request, 26 Sep
-- 2026): members of one Yojna pay different amounts for each closing. The
-- office sets it on the member form; an agent sets it when enrolling, and the
-- office can correct it.
--
-- Every existing member starts at their Yojna's current amount, so no one's
-- dues change on the day this goes live. `yojnas.contribution_amount` stays in
-- the table but nothing reads it any more.
--
-- Dues are worked out live from the member's amount, so changing it changes
-- what they owe on closings they have not paid yet. Payments already made are
-- untouched.
--
-- The certificate now prints the label as "प्रत्येक <Yojna> सहयोग राशि" (e.g.
-- प्रत्येक शादी सहयोग राशि). A Yojna gains an optional [short_name], the word
-- that goes in the middle; left empty, the app takes it from the Yojna name.

alter table public.yojnas
  add column short_name text not null default '';

alter table public.members
  add column contribution_amount numeric(12, 2) not null default 0
    check (contribution_amount >= 0);

update public.members m
   set contribution_amount = y.contribution_amount
  from public.yojnas y
 where y.id = m.yojna_id;

-- ---------------------------------------------------------------------------
-- Dues: each member owes their own amount
-- ---------------------------------------------------------------------------

-- Same columns as 20260928000300_closing_per_case.sql; only [amount] and
-- [due] change source.
create or replace view public.member_dues with (security_invoker = true) as
select c.yojna_id,
       c.closing_group,
       c.closing_date,
       c.id as closing_case_id,
       1::bigint as case_count,
       m.id as member_id,
       m.agent_id,
       m.contribution_amount as amount,
       coalesce(sum(p.amount) filter (where p.status = 'paid'), 0) as paid,
       coalesce(sum(p.amount) filter (where p.status = 'pending'), 0) as pending,
       greatest(m.contribution_amount
                - coalesce(sum(p.amount) filter (where p.status = 'paid'), 0), 0) as due,
       b.name as beneficiary_name
  from public.closing_cases c
  join public.members b on b.id = c.member_id
  join public.members m
    on m.yojna_id = c.yojna_id
   and m.status = 'active'
   and m.id <> c.member_id
   and m.created_at <= c.created_at
  left join public.payments p
    on p.member_id = m.id
   and p.kind = 'contribution'
   and p.cancelled_at is null
   and p.closing_case_id = c.id
 group by c.id, c.yojna_id, c.closing_group, c.closing_date, b.name,
          m.id, m.agent_id, m.contribution_amount;

-- ---------------------------------------------------------------------------
-- Office Dues page: the member's amount, for the payment form
-- ---------------------------------------------------------------------------

-- Gains [contribution_amount], so it is dropped and made again.
-- `office_dues_totals` calls it by name and keeps working.
drop function public.office_member_dues(uuid, text, uuid, boolean);

create function public.office_member_dues(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_agent_id uuid default null,
  p_owing    boolean default null
)
returns table (
  id uuid, yojna_id uuid, reg_no text, name text, primary_phone text,
  village text, agent_id uuid, status public.member_status, join_date date,
  closings_owed bigint, due numeric, pending numeric, contributed numeric,
  last_contribution date, contribution_amount numeric
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
begin
  perform public.require_admin();
  return query
  with owed as (
    select d.member_id,
           count(*) filter (where d.due > 0) as closings_owed,
           sum(d.due) as due,
           sum(d.pending) as pending
      from public.member_dues d
     where p_yojna_id is null or d.yojna_id = p_yojna_id
     group by d.member_id
  ), paid as (
    select p.member_id,
           sum(p.amount) as contributed,
           max(p.date) as last_contribution
      from public.payments p
     where p.kind = 'contribution'
       and p.status = 'paid'
       and p.cancelled_at is null
       and (p_yojna_id is null or p.yojna_id = p_yojna_id)
     group by p.member_id
  )
  select m.id, m.yojna_id, m.reg_no, m.name, m.primary_phone, m.village,
         m.agent_id, m.status, m.join_date,
         coalesce(o.closings_owed, 0), coalesce(o.due, 0), coalesce(o.pending, 0),
         coalesce(pd.contributed, 0), pd.last_contribution, m.contribution_amount
    from public.members m
    left join owed o on o.member_id = m.id
    left join paid pd on pd.member_id = m.id
   where m.status in ('active', 'inactive')
     and (p_yojna_id is null or m.yojna_id = p_yojna_id)
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_agent_id is null or m.agent_id = p_agent_id)
     and (p_owing is null or (coalesce(o.due, 0) > 0) = p_owing)
   order by coalesce(o.due, 0) desc, m.name, m.reg_no;
end $$;

revoke all on function public.office_member_dues(uuid, text, uuid, boolean)
from public, anon;
grant execute on function public.office_member_dues(uuid, text, uuid, boolean)
to authenticated;

-- ---------------------------------------------------------------------------
-- Agent: sees and sets the amount
-- ---------------------------------------------------------------------------

-- Gains [contribution_amount], so it is dropped and made again (as in
-- 20260928000100_agent_member_email.sql).
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
  closing_group text, review_note text, photo_url text, email text,
  contribution_amount numeric
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
         m.closing_date, m.closing_group, m.review_note, m.photo_url, m.email,
         m.contribution_amount
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

-- The agent enters the amount when enrolling; it must be more than zero.
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
    photo_url, contribution_amount
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
    amt
  ) returning id into new_id;
  return new_id;
end $$;

-- ---------------------------------------------------------------------------
-- Member portal and public lookup: the member's own amount
-- ---------------------------------------------------------------------------

-- Returns the member's own amount, and gains the Yojna's [short_name] for the
-- certificate. The return type changes, so the function is dropped and made
-- again; its grant is given back below.
drop function public.my_membership();

create function public.my_membership()
returns table (
  member_id uuid, reg_no text, name text, father_or_husband_name text,
  waris_name text, waris_relation text, primary_phone text, alt_phone text,
  village text, tehsil text, district text, pincode text,
  yojna_id uuid, yojna_name text, contribution_amount numeric,
  join_date date, status public.member_status, agent_name text,
  jati text, gotra text, dob date, state text, email text, photo_url text,
  yojna_description text, yojna_start_date date, yojna_short_name text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select m.id, m.reg_no, m.name, m.father_or_husband_name,
         m.waris_name, m.waris_relation, m.primary_phone, m.alt_phone,
         m.village, m.tehsil, m.district, m.pincode,
         m.yojna_id, y.name, m.contribution_amount,
         m.join_date, m.status, coalesce(a.name, ''),
         m.jati, m.gotra, m.dob, m.state, m.email, m.photo_url,
         y.description, y.start_date, y.short_name
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.agents a on a.id = m.agent_id
   where m.id = v_id;
end $$;

revoke all on function public.my_membership() from public, anon;
grant execute on function public.my_membership() to authenticated;

-- Same return type as 20260927000100_lookup_records.sql; the certificate
-- details gain the Yojna's [short_name].
create or replace function public.member_lookup(p_phone text, p_aadhaar4 text)
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
  select m.reg_no, m.name, y.name, m.status, m.join_date, m.contribution_amount,
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
             'yojna_short_name', y.short_name,
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

-- ---------------------------------------------------------------------------
-- Agent: the Yojna's short name, for the certificates agents print
-- ---------------------------------------------------------------------------

-- Drops [contribution_amount] (now per member) and adds [short_name]. The
-- return type changes, so the function is dropped and made again.
-- `agent_add_member` calls it by name and keeps working.
drop function public.agent_yojnas();

create function public.agent_yojnas()
returns table (
  id uuid, name text, code text, description text,
  registration_fee numeric, start_date date, short_name text
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select y.id, y.name, y.code, y.description,
         y.registration_fee, y.start_date, y.short_name
    from public.yojnas y
    join public.agents ag on ag.id = a
   where y.is_active
     and (cardinality(ag.yojna_ids) = 0 or y.id = any (ag.yojna_ids))
   order by y.name;
end $$;

revoke all on function public.agent_yojnas() from public, anon;
grant execute on function public.agent_yojnas() to authenticated;
