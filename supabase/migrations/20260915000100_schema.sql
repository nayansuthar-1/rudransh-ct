-- Rudransh CT core schema: tables, constraints, numbering, sync triggers.
-- Column names are snake_case versions of the Dart model fields, and enum
-- values match the Dart enum `name`s so mapping stays one-to-one.

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------

create type public.gender as enum ('male', 'female', 'other');
create type public.member_status as enum ('active', 'inactive', 'closed');
create type public.payment_mode as enum ('cash', 'upi', 'bank', 'cheque');
create type public.payment_status as enum ('paid', 'pending', 'failed');
create type public.payment_kind as enum ('registration', 'contribution', 'closingPayout');
create type public.closing_pay_status as enum ('unpaid', 'partial', 'paid');

-- ---------------------------------------------------------------------------
-- Shared helpers
-- ---------------------------------------------------------------------------

create function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- Admins
-- ---------------------------------------------------------------------------

create table public.admins (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  name       text not null default '',
  email      text not null default '',
  role       text not null default 'ADMIN',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Counters (atomic numbering)
-- ---------------------------------------------------------------------------

create table public.counters (
  key   text primary key,
  value integer not null check (value >= 0)
);

-- Row-locked upsert, so two admins saving at once never get the same number.
create function public.next_number(k text) returns integer
language sql security definer set search_path = '' as $$
  insert into public.counters (key, value) values (k, 1)
  on conflict (key) do update set value = public.counters.value + 1
  returning value;
$$;

-- Zero-pads to at least [width] digits. Plain lpad() truncates longer values,
-- which would turn registration 10000 into a duplicate of 1000.
create function public.zero_pad(n integer, width integer) returns text
language sql immutable set search_path = '' as $$
  select lpad(n::text, greatest(width, length(n::text)), '0');
$$;

-- ---------------------------------------------------------------------------
-- Yojnas
-- ---------------------------------------------------------------------------

create table public.yojnas (
  id                  uuid primary key default gen_random_uuid(),
  name                text not null check (length(trim(name)) > 0),
  code                text not null unique check (code ~ '^[A-Z]{2,6}$'),
  description         text not null default '',
  contribution_amount numeric(12, 2) not null default 0 check (contribution_amount >= 0),
  claim_amount        numeric(12, 2) not null default 0 check (claim_amount >= 0),
  registration_fee    numeric(12, 2) not null default 0 check (registration_fee >= 0),
  is_active           boolean not null default true,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger yojnas_touch before update on public.yojnas
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Agents
-- ---------------------------------------------------------------------------

create table public.agents (
  id                 uuid primary key default gen_random_uuid(),
  code               text not null unique check (code ~ '^AG-\d{3,}$'),
  name               text not null check (length(trim(name)) > 0),
  phone              text not null default '' check (phone = '' or phone ~ '^\d{10}$'),
  email              text not null default '',
  area               text not null default '',
  district           text not null default '',
  commission_percent numeric(5, 2) not null default 0
                     check (commission_percent between 0 and 100),
  -- Schemes this agent may work on. Empty means all.
  yojna_ids          uuid[] not null default '{}',
  is_active          boolean not null default true,
  join_date          date not null default current_date,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create function public.set_agent_code() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.code := 'AG-' || public.zero_pad(public.next_number('AG'), 3);
  return new;
end $$;

create trigger agents_code before insert on public.agents
  for each row when (new.code is null or new.code = '')
  execute function public.set_agent_code();

create trigger agents_touch before update on public.agents
  for each row execute function public.touch_updated_at();

-- yojna_ids has no foreign key, so drop a deleted scheme from every agent.
create function public.remove_yojna_from_agents() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  update public.agents set yojna_ids = array_remove(yojna_ids, old.id)
   where old.id = any (yojna_ids);
  return old;
end $$;

create trigger yojnas_cleanup_agents after delete on public.yojnas
  for each row execute function public.remove_yojna_from_agents();

-- ---------------------------------------------------------------------------
-- Members
-- ---------------------------------------------------------------------------

create table public.members (
  id                     uuid primary key default gen_random_uuid(),
  yojna_id               uuid not null references public.yojnas (id),
  reg_no                 text not null unique,
  name                   text not null check (length(trim(name)) > 0),
  father_or_husband_name text not null default '',
  jati                   text not null default '',
  gotra                  text not null default '',
  waris_name             text not null default '',
  waris_relation         text not null default '',
  gender                 public.gender not null default 'male',
  primary_phone          text not null check (primary_phone ~ '^\d{10}$'),
  alt_phone              text not null default '' check (alt_phone = '' or alt_phone ~ '^\d{10}$'),
  -- TODO(privacy): pending client/legal decision, see IMPLEMENTATION_PLAN §7.
  aadhaar                text not null default '' check (aadhaar = '' or aadhaar ~ '^\d{12}$'),
  village                text not null default '',
  tehsil                 text not null default '',
  district               text not null default '',
  pincode                text not null default '' check (pincode = '' or pincode ~ '^\d{6}$'),
  agent_id               uuid references public.agents (id) on delete set null,
  join_date              date not null default current_date,
  status                 public.member_status not null default 'active',
  closing_date           date,
  closing_group          text,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now()
);

create index members_yojna_idx on public.members (yojna_id);
create index members_agent_idx on public.members (agent_id);
create index members_status_idx on public.members (status);
create index members_primary_phone_idx on public.members (primary_phone);
create index members_alt_phone_idx on public.members (alt_phone) where alt_phone <> '';
create index members_join_date_idx on public.members (join_date desc);

-- Registration number `SSY-2026-0184`, one counter per scheme per year.
create function public.set_reg_no() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  c text;
  prefix text;
begin
  select code into c from public.yojnas where id = new.yojna_id;
  if c is null then
    raise exception 'Yojna % not found', new.yojna_id using errcode = '23503';
  end if;
  prefix := c || '-' || extract(year from now() at time zone 'Asia/Kolkata')::int;
  new.reg_no := prefix || '-' || public.zero_pad(public.next_number(prefix), 4);
  return new;
end $$;

create trigger members_reg_no before insert on public.members
  for each row when (new.reg_no is null or new.reg_no = '')
  execute function public.set_reg_no();

create trigger members_touch before update on public.members
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Payments
-- ---------------------------------------------------------------------------

create table public.payments (
  id         uuid primary key default gen_random_uuid(),
  receipt_no text not null unique,
  member_id  uuid not null references public.members (id),
  yojna_id   uuid not null references public.yojnas (id),
  amount     numeric(12, 2) not null check (amount > 0),
  date       date not null default current_date,
  mode       public.payment_mode not null default 'cash',
  status     public.payment_status not null default 'paid',
  kind       public.payment_kind not null default 'contribution',
  agent_id   uuid references public.agents (id) on delete set null,
  -- UTR / cheque number / UPI reference.
  reference  text not null default '',
  note       text not null default '',
  created_by uuid default auth.uid() references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index payments_member_idx on public.payments (member_id);
create index payments_yojna_date_idx on public.payments (yojna_id, date desc);
create index payments_date_idx on public.payments (date desc);
create index payments_agent_idx on public.payments (agent_id);

-- Receipt number `RCP-1001` onwards.
create function public.set_receipt_no() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.receipt_no := 'RCP-' || (1000 + public.next_number('RCP'))::text;
  return new;
end $$;

create trigger payments_receipt_no before insert on public.payments
  for each row when (new.receipt_no is null or new.receipt_no = '')
  execute function public.set_receipt_no();

create trigger payments_touch before update on public.payments
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------------
-- Closing cases
-- ---------------------------------------------------------------------------

create table public.closing_cases (
  id               uuid primary key default gen_random_uuid(),
  member_id        uuid not null unique references public.members (id) on delete cascade,
  yojna_id         uuid not null references public.yojnas (id),
  closing_date     date not null default current_date,
  closing_group    text not null default '',
  claim_amount     numeric(12, 2) not null default 0 check (claim_amount >= 0),
  collected_amount numeric(12, 2) not null default 0 check (collected_amount >= 0),
  pay_status       public.closing_pay_status not null default 'unpaid',
  nominee_name     text not null default '',
  remarks          text not null default '',
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create index closing_cases_yojna_date_idx on public.closing_cases (yojna_id, closing_date desc);

create trigger closing_cases_touch before update on public.closing_cases
  for each row execute function public.touch_updated_at();

-- Keep the member row in step with its closing case.
create function public.sync_member_on_closing() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    update public.members
       set status = 'closed', closing_date = new.closing_date,
           closing_group = new.closing_group
     where id = new.member_id;
  elsif tg_op = 'UPDATE' then
    update public.members
       set closing_date = new.closing_date, closing_group = new.closing_group
     where id = new.member_id;
  elsif tg_op = 'DELETE' and pg_trigger_depth() = 1 then
    -- Depth > 1 means the member itself is being deleted (cascade); skip.
    update public.members
       set status = 'active', closing_date = null, closing_group = null
     where id = old.member_id;
  end if;
  return null;
end $$;

create trigger closing_cases_sync_member
  after insert or update of closing_date, closing_group or delete
  on public.closing_cases
  for each row execute function public.sync_member_on_closing();
