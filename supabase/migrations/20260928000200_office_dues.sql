-- The office's Dues page (25 Sep 2026): every member of a Yojna with what
-- they still owe across all its closing groups, what is collected but waiting
-- for approval, and every contribution they have paid so far.
--
-- Dues come from the `member_dues` view (20260919000100_dues.sql), so the
-- rules stay the same: only active members who joined before a group's first
-- closing date owe for it. Members waiting for approval (no registration yet)
-- and closed members are left out of the list.

-- One row per member, most owed first. Page with PostgREST `.range()`.
-- [p_owing] true lists only members who still owe, false only those who owe
-- nothing, null everyone.
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
  last_contribution date
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
         coalesce(pd.contributed, 0), pd.last_contribution
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

-- The tiles above the list: across every page, ignoring the owing filter so
-- the tiles always show the whole Yojna.
create function public.office_dues_totals(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_agent_id uuid default null
)
returns table (
  member_count bigint, owing_count bigint, due numeric, pending numeric,
  contributed numeric
)
language sql stable set search_path = '' as $$
  select count(*),
         count(*) filter (where d.due > 0),
         coalesce(sum(d.due), 0),
         coalesce(sum(d.pending), 0),
         coalesce(sum(d.contributed), 0)
    from public.office_member_dues(p_yojna_id, p_query, p_agent_id) d;
$$;

revoke all on function public.office_member_dues(uuid, text, uuid, boolean)
from public, anon;
grant execute on function public.office_member_dues(uuid, text, uuid, boolean)
to authenticated;

revoke all on function public.office_dues_totals(uuid, text, uuid)
from public, anon;
grant execute on function public.office_dues_totals(uuid, text, uuid)
to authenticated;
