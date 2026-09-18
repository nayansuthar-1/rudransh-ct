-- Release 2, Phase 14 (IMPLEMENTATION_PLAN §11): notifications and announcements.
--
-- The `notifications` and `announcements` tables came with
-- 20260917000200_roles.sql; this migration fills them and hands them out.
--
-- Notifications are written by triggers on the events an agent or admin would
-- otherwise have to go looking for: a payment approved or rejected, a death
-- report decided, a new closing, members moved between agents. Overdue dues
-- are not an event, so they come from a function meant to be run daily
-- (`notify_overdue_dues`); see docs/RUNBOOK.md.
--
-- As in 20260918000100_agent_work.sql, agents and members only reach this data
-- through SECURITY DEFINER functions.

-- ---------------------------------------------------------------------------
-- Writing a notification
-- ---------------------------------------------------------------------------

-- The login behind an agent record, or null when the agent has no active
-- profile yet (invited but never signed in). Notifying them is then skipped.
create function public.agent_user_id(p_agent_id uuid) returns uuid
language sql stable security definer set search_path = '' as $$
  select p.user_id from public.profiles p
   where p.agent_id = p_agent_id and p.role = 'agent' and p.is_active;
$$;

-- Ignores a null recipient so callers don't have to check.
create function public.notify(
  p_user_id uuid, p_type text, p_title text,
  p_body text default '', p_link text default ''
) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id is null then return; end if;
  insert into public.notifications (user_id, type, title, body, link)
  values (p_user_id, p_type, p_title, p_body, p_link);
end $$;

-- ---------------------------------------------------------------------------
-- Triggers: payments approved or rejected
-- ---------------------------------------------------------------------------

-- Fires only on the change, so re-saving an approved payment stays quiet.
create function public.notify_payment_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid;
  v_name text;
begin
  if new.agent_id is null or new.status = old.status then
    return new;
  end if;
  v_user := public.agent_user_id(new.agent_id);
  if v_user is null then return new; end if;

  select m.name into v_name from public.members m where m.id = new.member_id;
  v_name := coalesce(v_name, 'a member');

  if old.status = 'pending' and new.status = 'paid' then
    perform public.notify(
      v_user, 'payment_approved', 'Payment approved',
      format('Rs %s from %s (receipt %s) is approved.',
             trim(to_char(new.amount, 'FM9999999')), v_name, new.receipt_no),
      '/agent/collections'
    );
  elsif old.status = 'pending' and new.status = 'failed' then
    perform public.notify(
      v_user, 'payment_rejected', 'Payment rejected',
      format('Rs %s from %s was rejected. %s',
             trim(to_char(new.amount, 'FM9999999')), v_name,
             coalesce(nullif(trim(new.reject_reason), ''), 'No reason given.')),
      '/agent/collections'
    );
  end if;
  return new;
end $$;

create trigger payments_notify_decision after update of status on public.payments
  for each row execute function public.notify_payment_decision();

-- ---------------------------------------------------------------------------
-- Triggers: a death report is decided
-- ---------------------------------------------------------------------------

create function public.notify_closing_request_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid;
  v_name text;
begin
  if new.status = old.status or new.agent_id is null then
    return new;
  end if;
  v_user := public.agent_user_id(new.agent_id);
  if v_user is null then return new; end if;

  select m.name into v_name from public.members m where m.id = new.member_id;
  v_name := coalesce(v_name, 'a member');

  if new.status = 'approved' then
    perform public.notify(
      v_user, 'closing_approved', 'Death report approved',
      format('The report for %s is approved and a closing case is open.', v_name),
      '/agent/dues'
    );
  elsif new.status = 'rejected' then
    perform public.notify(
      v_user, 'closing_rejected', 'Death report rejected',
      format('The report for %s was rejected. %s', v_name,
             coalesce(nullif(trim(new.decision_note), ''), 'No reason given.')),
      '/agent/dues'
    );
  end if;
  return new;
end $$;

create trigger closing_requests_notify_decision
  after update of status on public.closing_requests
  for each row execute function public.notify_closing_request_decision();

-- ---------------------------------------------------------------------------
-- Trigger: a new closing means everyone owes a contribution
-- ---------------------------------------------------------------------------

-- Told to every agent with an active member in that Yojna, because their
-- whole list now has something to collect.
create function public.notify_new_closing() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  v_yojna text;
  v_name  text;
  v_user  uuid;
begin
  select y.name into v_yojna from public.yojnas y where y.id = new.yojna_id;
  select m.name into v_name from public.members m where m.id = new.member_id;

  for v_user in
    select distinct public.agent_user_id(m.agent_id)
      from public.members m
     where m.yojna_id = new.yojna_id
       and m.status = 'active'
       and m.agent_id is not null
  loop
    perform public.notify(
      v_user, 'closing_new', 'New closing to collect for',
      format('%s in %s. Collect one contribution from each of your members.',
             coalesce(v_name, 'A member'), coalesce(v_yojna, 'a Yojna')),
      '/agent/dues'
    );
  end loop;
  return new;
end $$;

create trigger closing_cases_notify_new after insert on public.closing_cases
  for each row execute function public.notify_new_closing();

-- ---------------------------------------------------------------------------
-- Trigger: members moved between agents
-- ---------------------------------------------------------------------------

-- Both sides hear about it: one list grew, the other shrank.
create function public.notify_member_reassigned() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.agent_id is not distinct from old.agent_id then
    return new;
  end if;
  perform public.notify(
    public.agent_user_id(new.agent_id), 'member_assigned',
    'A member was moved to you',
    format('%s is now on your list.', new.name), '/agent/members'
  );
  perform public.notify(
    public.agent_user_id(old.agent_id), 'member_removed',
    'A member left your list',
    format('%s was moved to another agent.', new.name), '/agent/members'
  );
  return new;
end $$;

create trigger members_notify_reassigned after update of agent_id on public.members
  for each row execute function public.notify_member_reassigned();

-- ---------------------------------------------------------------------------
-- Overdue dues (run daily, not a trigger)
-- ---------------------------------------------------------------------------

-- One notification per agent per closing group that has been open longer than
-- [p_days] and still has members who have not paid. Re-running on the same day
-- does not repeat itself, so a retry after a failed run is safe.
create function public.notify_overdue_dues(p_days integer default 30)
returns integer
language plpgsql security definer set search_path = '' as $$
declare
  v_sent integer := 0;
  r      record;
  v_user uuid;
begin
  for r in
    select d.agent_id, d.yojna_id, d.closing_group, y.name as yojna_name,
           count(*) as still_due
      from public.member_dues d
      join public.yojnas y on y.id = d.yojna_id
     where d.due > 0
       and d.agent_id is not null
       and d.closing_date <= current_date - p_days
     group by d.agent_id, d.yojna_id, d.closing_group, y.name
  loop
    v_user := public.agent_user_id(r.agent_id);
    if v_user is null then continue; end if;
    -- Already told today? Leave it.
    if exists (
      select 1 from public.notifications n
       where n.user_id = v_user and n.type = 'dues_overdue'
         and n.created_at >= current_date
         and n.link = '/agent/dues'
         and n.body like '%' || r.closing_group || '%'
    ) then
      continue;
    end if;
    perform public.notify(
      v_user, 'dues_overdue', 'Dues are overdue',
      format('%s member(s) have not paid for %s in %s, open more than %s days.',
             r.still_due, r.closing_group, r.yojna_name, p_days),
      '/agent/dues'
    );
    v_sent := v_sent + 1;
  end loop;
  return v_sent;
end $$;

-- ---------------------------------------------------------------------------
-- Reading your own notifications
-- ---------------------------------------------------------------------------

create function public.my_notifications(
  p_limit integer default 30, p_offset integer default 0
)
returns table (
  id bigint, type text, title text, body text, link text,
  read_at timestamptz, created_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select n.id, n.type, n.title, n.body, n.link, n.read_at, n.created_at
    from public.notifications n
   where n.user_id = (select auth.uid())
   order by n.created_at desc
   limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
$$;

create function public.my_unread_count() returns integer
language sql stable security definer set search_path = '' as $$
  select count(*)::integer from public.notifications n
   where n.user_id = (select auth.uid()) and n.read_at is null;
$$;

create function public.mark_notification_read(p_id bigint) returns void
language sql security definer set search_path = '' as $$
  update public.notifications set read_at = now()
   where id = p_id and user_id = (select auth.uid()) and read_at is null;
$$;

create function public.mark_all_notifications_read() returns integer
language plpgsql security definer set search_path = '' as $$
declare v_count integer;
begin
  with done as (
    update public.notifications set read_at = now()
     where user_id = (select auth.uid()) and read_at is null
     returning 1
  )
  select count(*)::integer into v_count from done;
  return v_count;
end $$;

-- ---------------------------------------------------------------------------
-- Announcements
-- ---------------------------------------------------------------------------

-- Admins post; a null Yojna means everybody.
create function public.post_announcement(
  p_title text, p_body text default '', p_yojna_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  perform public.require_admin();
  if length(trim(coalesce(p_title, ''))) = 0 then
    raise exception 'Give the announcement a title.';
  end if;
  insert into public.announcements (yojna_id, title, body)
  values (p_yojna_id, trim(p_title), coalesce(p_body, ''))
  returning id into v_id;
  return v_id;
end $$;

create function public.delete_announcement(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform public.require_admin();
  delete from public.announcements where id = p_id;
  if not found then
    raise exception 'That announcement is already gone.';
  end if;
end $$;

-- What the signed-in user should see: admins see everything, an agent sees
-- announcements for every Yojna their members belong to, a member sees their
-- own Yojna. Trust-wide announcements reach all three.
create function public.my_announcements(
  p_limit integer default 20, p_offset integer default 0
)
returns table (
  id uuid, yojna_id uuid, yojna_name text, title text, body text,
  published_at timestamptz
)
language sql stable security definer set search_path = '' as $$
  select a.id, a.yojna_id, coalesce(y.name, ''), a.title, a.body, a.published_at
    from public.announcements a
    left join public.yojnas y on y.id = a.yojna_id
   where a.published_at <= now()
     and (
       a.yojna_id is null
       or public.is_admin()
       or (public.my_role() = 'agent' and exists (
             select 1 from public.members m
              where m.agent_id = public.my_agent_id() and m.yojna_id = a.yojna_id
           ))
       or (public.my_role() = 'member' and exists (
             select 1 from public.members m
              where m.id = public.my_member_id() and m.yojna_id = a.yojna_id
           ))
     )
   order by a.published_at desc
   limit greatest(1, least(p_limit, 100)) offset greatest(0, p_offset);
$$;

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- The helpers are building blocks for the triggers, not app entry points.
-- `notify_overdue_dues` is run by the scheduled job as the service role.
revoke execute on function
  public.notify(uuid, text, text, text, text),
  public.agent_user_id(uuid),
  public.notify_overdue_dues(integer)
from public, anon, authenticated;

grant execute on function
  public.my_notifications(integer, integer),
  public.my_unread_count(),
  public.mark_notification_read(bigint),
  public.mark_all_notifications_read(),
  public.my_announcements(integer, integer),
  public.post_announcement(text, text, uuid),
  public.delete_announcement(uuid)
to authenticated;
