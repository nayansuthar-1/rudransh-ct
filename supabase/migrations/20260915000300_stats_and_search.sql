-- Server-side aggregates and search. PostgREST returns at most 1,000 rows per
-- request, so totals must be computed here rather than summed in the app.
-- All functions are SECURITY INVOKER: row-level security still applies.

create extension if not exists pg_trgm with schema extensions;

-- ---------------------------------------------------------------------------
-- Search columns + trigram indexes
-- ---------------------------------------------------------------------------

alter table public.members add column search_text text generated always as (
  lower(
    name || ' ' || reg_no || ' ' || father_or_husband_name || ' ' ||
    primary_phone || ' ' || alt_phone || ' ' || village || ' ' ||
    district || ' ' || waris_name
  )
) stored;

create index members_search_trgm on public.members
  using gin (search_text extensions.gin_trgm_ops);

alter table public.payments add column search_text text generated always as (
  lower(receipt_no || ' ' || reference)
) stored;

create index payments_search_trgm on public.payments
  using gin (search_text extensions.gin_trgm_ops);

create index agents_search_trgm on public.agents
  using gin (lower(name || ' ' || code || ' ' || phone || ' ' || email || ' ' ||
                   area || ' ' || district) extensions.gin_trgm_ops);

-- `100%_off` typed by a user must match literally, not as a pattern.
create function public.like_pattern(q text) returns text
language sql immutable set search_path = '' as $$
  select '%' || replace(replace(replace(lower(trim(q)), '\', '\\'), '%', '\%'), '_', '\_') || '%';
$$;

-- Today in India, so "this month" does not flip at 05:30 IST.
create function public.today_ist() returns date
language sql stable set search_path = '' as $$
  select (now() at time zone 'Asia/Kolkata')::date;
$$;

-- ---------------------------------------------------------------------------
-- Members
-- ---------------------------------------------------------------------------

-- Use with PostgREST `.range()` and `count: exact` for paging.
create function public.search_members(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_status   public.member_status default null,
  p_agent_id uuid default null,
  p_district text default null
) returns setof public.members
language sql stable set search_path = '' as $$
  select m.*
    from public.members m
   where (p_yojna_id is null or m.yojna_id = p_yojna_id)
     and (coalesce(trim(p_query), '') = '' or m.search_text like public.like_pattern(p_query))
     and (p_status is null or m.status = p_status)
     and (p_agent_id is null or m.agent_id = p_agent_id)
     and (p_district is null or m.district = p_district)
   order by m.join_date desc, m.reg_no desc;
$$;

create function public.member_districts() returns setof text
language sql stable set search_path = '' as $$
  select distinct district from public.members
   where trim(district) <> '' order by district;
$$;

create function public.members_per_yojna()
returns table (yojna_id uuid, member_count bigint)
language sql stable set search_path = '' as $$
  select yojna_id, count(*) from public.members group by yojna_id;
$$;

create function public.member_count_by_agent()
returns table (agent_id uuid, member_count bigint)
language sql stable set search_path = '' as $$
  select agent_id, count(*) from public.members
   where agent_id is not null group by agent_id;
$$;

-- ---------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------

create function public.search_payments(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_mode     public.payment_mode default null,
  p_status   public.payment_status default null,
  p_kind     public.payment_kind default null,
  p_from     date default null,
  p_to       date default null,
  p_member_id uuid default null
) returns setof public.payments
language sql stable set search_path = '' as $$
  select p.*
    from public.payments p
   where (p_yojna_id is null or p.yojna_id = p_yojna_id)
     and (p_member_id is null or p.member_id = p_member_id)
     and (p_mode is null or p.mode = p_mode)
     and (p_status is null or p.status = p_status)
     and (p_kind is null or p.kind = p_kind)
     and (p_from is null or p.date >= p_from)
     and (p_to is null or p.date <= p_to)
     and (
       coalesce(trim(p_query), '') = ''
       or p.search_text like public.like_pattern(p_query)
       or p.member_id in (
         select m.id from public.members m
          where m.search_text like public.like_pattern(p_query)
       )
     )
   order by p.date desc, p.receipt_no desc;
$$;

create function public.payment_totals(
  p_yojna_id uuid default null,
  p_query    text default null,
  p_mode     public.payment_mode default null,
  p_status   public.payment_status default null,
  p_kind     public.payment_kind default null,
  p_from     date default null,
  p_to       date default null,
  p_member_id uuid default null
) returns table (count bigint, paid numeric, pending numeric, failed numeric)
language sql stable set search_path = '' as $$
  select count(*),
         coalesce(sum(amount) filter (where status = 'paid'), 0),
         coalesce(sum(amount) filter (where status = 'pending'), 0),
         coalesce(sum(amount) filter (where status = 'failed'), 0)
    from public.search_payments(p_yojna_id, p_query, p_mode, p_status, p_kind, p_from, p_to, p_member_id);
$$;

-- Paid total per month for the last `p_months` months, oldest first.
create function public.monthly_collection(
  p_yojna_id uuid default null,
  p_months   int default 6
) returns table (month date, total numeric)
language sql stable set search_path = '' as $$
  with months as (
    select generate_series(
             date_trunc('month', public.today_ist()) - make_interval(months => p_months - 1),
             date_trunc('month', public.today_ist()),
             interval '1 month')::date as month
  )
  select mo.month, coalesce(sum(p.amount), 0)
    from months mo
    left join public.payments p
      on p.status = 'paid'
     and p.date >= mo.month
     and p.date < (mo.month + interval '1 month')::date
     and (p_yojna_id is null or p.yojna_id = p_yojna_id)
   group by mo.month
   order by mo.month;
$$;

create function public.collection_by_agent(p_yojna_id uuid default null)
returns table (agent_id uuid, total numeric)
language sql stable set search_path = '' as $$
  select agent_id, sum(amount) from public.payments
   where agent_id is not null and status = 'paid'
     and (p_yojna_id is null or yojna_id = p_yojna_id)
   group by agent_id;
$$;

-- ---------------------------------------------------------------------------
-- Dashboard
-- ---------------------------------------------------------------------------

create function public.dashboard_stats(p_yojna_id uuid default null)
returns table (
  total_members             bigint,
  active_members            bigint,
  inactive_members          bigint,
  closed_members            bigint,
  total_agents              bigint,
  active_agents             bigint,
  month_collection          numeric,
  previous_month_collection numeric,
  pending_claims            numeric
)
language sql stable set search_path = '' as $$
  with bounds as (
    select date_trunc('month', public.today_ist())::date as month_start,
           (date_trunc('month', public.today_ist()) - interval '1 month')::date as prev_start
  ),
  m as (
    select count(*) as total,
           count(*) filter (where status = 'active') as active,
           count(*) filter (where status = 'inactive') as inactive,
           count(*) filter (where status = 'closed') as closed
      from public.members
     where p_yojna_id is null or yojna_id = p_yojna_id
  ),
  a as (
    select count(*) as total, count(*) filter (where is_active) as active
      from public.agents
  ),
  p as (
    select coalesce(sum(amount) filter (where date >= b.month_start), 0) as month_total,
           coalesce(sum(amount) filter (where date >= b.prev_start and date < b.month_start), 0) as prev_total
      from public.payments, bounds b
     where status = 'paid'
       and date >= b.prev_start
       and (p_yojna_id is null or yojna_id = p_yojna_id)
  ),
  c as (
    select coalesce(sum(greatest(claim_amount - collected_amount, 0)), 0) as pending
      from public.closing_cases
     where pay_status <> 'paid'
       and (p_yojna_id is null or yojna_id = p_yojna_id)
  )
  select m.total, m.active, m.inactive, m.closed, a.total, a.active,
         p.month_total, p.prev_total, c.pending
    from m, a, p, c;
$$;

-- ---------------------------------------------------------------------------
-- Grants (functions were revoked from anon/public by default)
-- ---------------------------------------------------------------------------

grant execute on function
  public.like_pattern(text),
  public.today_ist(),
  public.search_members(uuid, text, public.member_status, uuid, text),
  public.member_districts(),
  public.members_per_yojna(),
  public.member_count_by_agent(),
  public.search_payments(uuid, text, public.payment_mode, public.payment_status, public.payment_kind, date, date, uuid),
  public.payment_totals(uuid, text, public.payment_mode, public.payment_status, public.payment_kind, date, date, uuid),
  public.monthly_collection(uuid, int),
  public.collection_by_agent(uuid),
  public.dashboard_stats(uuid)
to authenticated;
