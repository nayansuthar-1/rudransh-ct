-- A signed-in member's certificate printed blank lines for gotra, jati, date
-- of birth, state and photo, and without the Yojna's नोंध and start date:
-- `my_membership` never returned them. It does now, plus the member's email.
--
-- The return type changes, so the function is dropped and made again; its
-- grant goes with it and is given back below.

drop function public.my_membership();

create function public.my_membership()
returns table (
  member_id uuid, reg_no text, name text, father_or_husband_name text,
  waris_name text, waris_relation text, primary_phone text, alt_phone text,
  village text, tehsil text, district text, pincode text,
  yojna_id uuid, yojna_name text, contribution_amount numeric,
  join_date date, status public.member_status, agent_name text,
  jati text, gotra text, dob date, state text, email text, photo_url text,
  yojna_description text, yojna_start_date date
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select m.id, m.reg_no, m.name, m.father_or_husband_name,
         m.waris_name, m.waris_relation, m.primary_phone, m.alt_phone,
         m.village, m.tehsil, m.district, m.pincode,
         m.yojna_id, y.name, y.contribution_amount,
         m.join_date, m.status, coalesce(a.name, ''),
         m.jati, m.gotra, m.dob, m.state, m.email, m.photo_url,
         y.description, y.start_date
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.agents a on a.id = m.agent_id
   where m.id = v_id;
end $$;

revoke all on function public.my_membership() from public, anon;
grant execute on function public.my_membership() to authenticated;
