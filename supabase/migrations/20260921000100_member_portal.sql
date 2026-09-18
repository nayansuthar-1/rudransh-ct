-- Release 2, Phase 15 (IMPLEMENTATION_PLAN §11): the member portal.
--
-- Three ways in, in order of how much the caller has proved:
--
--   1. Public lookup. No login. The `member_lookup` function is granted to
--      `service_role` only and is called by the `member_lookup` Edge Function,
--      which checks Cloudflare Turnstile first. Nothing here is reachable by
--      `anon`, so a stolen publishable key still reads no member data.
--   2. A signed-in member (invited by an admin, email OTP) reading their own
--      record through `my_*` functions.
--   3. Admins, under their existing access rules.
--
-- Members never write to `members` directly. A correction goes through
-- `request_change`, and an admin applies it.

-- ---------------------------------------------------------------------------
-- Public lookup
-- ---------------------------------------------------------------------------

-- Five wrong tries for one registration number within 15 minutes and that
-- number is locked for the rest of the window. Counted per reg no rather than
-- per IP: the database cannot see an IP, and it is the number being guessed.
create function public.lookup_locked(p_reg_no text) returns boolean
language sql stable security definer set search_path = '' as $$
  select count(*) >= 5
    from public.lookup_attempts a
   where a.reg_no = p_reg_no
     and not a.succeeded
     and a.created_at > now() - interval '15 minutes';
$$;

-- Reg no + phone + the last four Aadhaar digits. Returns one row, or nothing.
--
-- The Aadhaar check is skipped for a member whose Aadhaar was never recorded
-- (the column is optional, IMPLEMENTATION_PLAN §7); reg no and phone must
-- always match. Only a summary comes back: no Aadhaar, no address, no agent.
create function public.member_lookup(
  p_reg_no text, p_phone text, p_aadhaar4 text
)
returns table (
  reg_no text, name text, yojna_name text, status public.member_status,
  join_date date, contribution_amount numeric, dues_count bigint,
  dues_amount numeric
)
language plpgsql security definer set search_path = '' as $$
declare
  v_reg   text := upper(trim(coalesce(p_reg_no, '')));
  v_phone text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_a4    text := regexp_replace(coalesce(p_aadhaar4, ''), '\D', '', 'g');
  v_id    uuid;
begin
  if v_reg = '' or v_phone = '' then
    raise exception 'Enter the registration number and phone number.';
  end if;
  if public.lookup_locked(v_reg) then
    raise exception 'Too many wrong tries. Try again after 15 minutes.'
      using errcode = 'P0001';
  end if;

  select m.id into v_id
    from public.members m
   where m.reg_no = v_reg
     and (m.primary_phone = v_phone or m.alt_phone = v_phone)
     and (m.aadhaar = '' or right(m.aadhaar, 4) = v_a4);

  insert into public.lookup_attempts (reg_no, succeeded)
  values (v_reg, v_id is not null);

  if v_id is null then
    return;
  end if;

  return query
  select m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount,
         count(d.closing_group) filter (where d.due > 0),
         coalesce(sum(d.due), 0)
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.member_dues d on d.member_id = m.id
   where m.id = v_id
   group by m.reg_no, m.name, y.name, m.status, m.join_date, y.contribution_amount;
end $$;

-- ---------------------------------------------------------------------------
-- A signed-in member reading their own record
-- ---------------------------------------------------------------------------

create function public.require_member() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.my_member_id();
begin
  if v_id is null then
    raise exception 'Only a member can do this.' using errcode = '42501';
  end if;
  return v_id;
end $$;

create function public.my_membership()
returns table (
  member_id uuid, reg_no text, name text, father_or_husband_name text,
  waris_name text, waris_relation text, primary_phone text, alt_phone text,
  village text, tehsil text, district text, pincode text,
  yojna_id uuid, yojna_name text, contribution_amount numeric,
  join_date date, status public.member_status, agent_name text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select m.id, m.reg_no, m.name, m.father_or_husband_name,
         m.waris_name, m.waris_relation, m.primary_phone, m.alt_phone,
         m.village, m.tehsil, m.district, m.pincode,
         m.yojna_id, y.name, y.contribution_amount,
         m.join_date, m.status, coalesce(a.name, '')
    from public.members m
    join public.yojnas y on y.id = m.yojna_id
    left join public.agents a on a.id = m.agent_id
   where m.id = v_id;
end $$;

-- Receipts, newest first. Cancelled ones are shown so a member can see what
-- happened to a receipt they were given.
create function public.my_member_payments(
  p_limit integer default 50, p_offset integer default 0
)
returns table (
  id uuid, receipt_no text, amount numeric, date date,
  mode public.payment_mode, status public.payment_status,
  kind public.payment_kind, reference text, reject_reason text,
  cancelled_at timestamptz, closing_group text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select p.id, p.receipt_no, p.amount, p.date, p.mode, p.status, p.kind,
         p.reference, p.reject_reason, p.cancelled_at,
         coalesce(c.closing_group, '')
    from public.payments p
    left join public.closing_cases c on c.id = p.closing_case_id
   where p.member_id = v_id
   order by p.date desc, p.created_at desc
   limit greatest(1, least(p_limit, 200)) offset greatest(0, p_offset);
end $$;

-- Closing groups this member still owes a contribution for, oldest first.
create function public.my_member_dues()
returns table (
  yojna_id uuid, closing_group text, closing_date date,
  closing_case_id uuid, amount numeric, paid numeric, pending numeric,
  due numeric
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select d.yojna_id, d.closing_group, d.closing_date, d.closing_case_id,
         d.amount, d.paid, d.pending, d.due
    from public.member_dues d
   where d.member_id = v_id
   order by d.closing_date;
end $$;

-- The member's own closing case, once the office has opened one.
create function public.my_closing_case()
returns table (
  closing_date date, closing_group text, claim_amount numeric,
  collected_amount numeric, pay_status public.closing_pay_status,
  nominee_name text
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select c.closing_date, c.closing_group, c.claim_amount, c.collected_amount,
         c.pay_status, c.nominee_name
    from public.closing_cases c
   where c.member_id = v_id;
end $$;

-- ---------------------------------------------------------------------------
-- Paying by UPI
-- ---------------------------------------------------------------------------

-- The member transfers money themselves and enters the UTR. It lands as a
-- pending payment for an admin to approve, exactly like an agent's collection,
-- so nothing counts until the office has seen the money.
create function public.member_submit_upi(
  p_amount numeric, p_reference text, p_closing_case_id uuid default null
) returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id      uuid := public.require_member();
  v_yojna   uuid;
  v_ref     text := trim(coalesce(p_reference, ''));
  v_payment uuid;
begin
  if p_amount is null or p_amount <= 0 then
    raise exception 'Enter the amount you paid.';
  end if;
  if length(v_ref) < 6 then
    raise exception 'Enter the UPI reference (UTR) from your payment app.';
  end if;
  if exists (
    select 1 from public.payments p
     where p.member_id = v_id and p.reference = v_ref and p.cancelled_at is null
  ) then
    raise exception 'That UPI reference is already recorded.';
  end if;

  select m.yojna_id into v_yojna from public.members m where m.id = v_id;

  insert into public.payments (
    receipt_no, member_id, yojna_id, amount, mode, status, kind,
    reference, source, closing_case_id
  )
  values (
    '', v_id, v_yojna, p_amount, 'upi', 'pending',
    (case when p_closing_case_id is null then 'registration' else 'contribution' end)
      ::public.payment_kind,
    v_ref, 'member', p_closing_case_id
  )
  returning id into v_payment;

  return v_payment;
end $$;

-- ---------------------------------------------------------------------------
-- Change requests
-- ---------------------------------------------------------------------------

-- A member asks for a correction; an admin applies it. One pending request per
-- field, so a member cannot queue ten edits of the same thing.
create function public.request_change(p_field text, p_new_value text)
returns uuid
language plpgsql security definer set search_path = '' as $$
declare
  v_id  uuid := public.require_member();
  v_old text;
  v_new text := trim(coalesce(p_new_value, ''));
  v_req uuid;
begin
  if v_new = '' then
    raise exception 'Enter the new value.';
  end if;
  if exists (
    select 1 from public.change_requests r
     where r.member_id = v_id and r.field = p_field and r.status = 'pending'
  ) then
    raise exception 'A change to this detail is already waiting for the office.';
  end if;

  execute format('select %I::text from public.members where id = $1', p_field)
    into v_old using v_id;

  insert into public.change_requests (member_id, field, old_value, new_value)
  values (v_id, p_field, coalesce(v_old, ''), v_new)
  returning id into v_req;
  return v_req;
exception
  when undefined_column or invalid_column_reference then
    raise exception 'That detail cannot be changed here.';
end $$;

create function public.my_change_requests()
returns table (
  id uuid, field text, old_value text, new_value text,
  status public.request_status, decision_note text, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
declare v_id uuid := public.require_member();
begin
  return query
  select r.id, r.field, r.old_value, r.new_value, r.status, r.decision_note,
         r.created_at
    from public.change_requests r
   where r.member_id = v_id
   order by r.created_at desc;
end $$;

-- Admin side.
create function public.pending_change_requests()
returns table (
  id uuid, member_id uuid, member_name text, reg_no text,
  field text, old_value text, new_value text, created_at timestamptz
)
language plpgsql stable security definer set search_path = '' as $$
begin
  perform public.require_admin();
  return query
  select r.id, r.member_id, m.name, m.reg_no, r.field, r.old_value,
         r.new_value, r.created_at
    from public.change_requests r
    join public.members m on m.id = r.member_id
   where r.status = 'pending'
   order by r.created_at;
end $$;

-- Applying writes the member row, which the audit trigger records.
create function public.approve_change_request(p_id uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  perform public.require_admin();
  select * into r from public.change_requests
   where id = p_id and status = 'pending';
  if not found then
    raise exception 'This change is no longer waiting for a decision.';
  end if;

  execute format('update public.members set %I = $1 where id = $2', r.field)
    using r.new_value, r.member_id;

  update public.change_requests
     set status = 'approved', decided_by = (select auth.uid()),
         decided_at = now(), decision_note = ''
   where id = p_id;
end $$;

create function public.reject_change_request(p_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare v_reason text := trim(coalesce(p_reason, ''));
begin
  perform public.require_admin();
  if v_reason = '' then
    raise exception 'Give a reason.';
  end if;
  update public.change_requests
     set status = 'rejected', decided_by = (select auth.uid()),
         decided_at = now(), decision_note = v_reason
   where id = p_id and status = 'pending';
  if not found then
    raise exception 'This change is no longer waiting for a decision.';
  end if;
end $$;

-- The member hears the outcome in the notification panel (Phase 14).
create function public.notify_change_request_decision() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_user uuid;
begin
  if new.status = old.status then return new; end if;
  select p.user_id into v_user from public.profiles p
   where p.member_id = new.member_id and p.role = 'member' and p.is_active;
  if v_user is null then return new; end if;

  if new.status = 'approved' then
    perform public.notify(
      v_user, 'change_approved', 'Your correction was applied',
      format('%s is now "%s".', replace(new.field, '_', ' '), new.new_value),
      '/me'
    );
  elsif new.status = 'rejected' then
    perform public.notify(
      v_user, 'change_rejected', 'Your correction was not applied',
      coalesce(nullif(new.decision_note, ''), 'No reason given.'), '/me'
    );
  end if;
  return new;
end $$;

create trigger change_requests_notify_decision
  after update of status on public.change_requests
  for each row execute function public.notify_change_request_decision();

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

-- The public lookup is reachable only by the Edge Function, which checks
-- Turnstile first. `anon` gets nothing.
revoke execute on function
  public.member_lookup(text, text, text),
  public.lookup_locked(text),
  public.require_member()
from public, anon, authenticated;

grant execute on function public.member_lookup(text, text, text) to service_role;

grant execute on function
  public.my_membership(),
  public.my_member_payments(integer, integer),
  public.my_member_dues(),
  public.my_closing_case(),
  public.member_submit_upi(numeric, text, uuid),
  public.request_change(text, text),
  public.my_change_requests(),
  public.pending_change_requests(),
  public.approve_change_request(uuid),
  public.reject_change_request(uuid, text)
to authenticated;
