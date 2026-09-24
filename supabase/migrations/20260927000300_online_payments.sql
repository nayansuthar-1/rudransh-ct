-- Online payments through Razorpay (client decision, 24 Sep 2026: the trust
-- pays Razorpay's fee; the member pays exactly what they owe).
--
-- The flow, all through Edge Functions running as the service role:
--
--   1. `razorpay_order`: a signed-in member picks a closing they owe for. The
--      amount comes from `member_dues` here, never from the app, and an order
--      row is written before Razorpay is asked for the order.
--   2. The member pays in Razorpay's checkout.
--   3. `razorpay_verify` (from the browser) and `razorpay_webhook` (from
--      Razorpay, in case the browser closed) both check Razorpay's signature
--      and call `record_online_payment`. Whichever arrives first records a
--      Paid receipt; the other finds it done. No office approval: Razorpay
--      has already confirmed the money.
--
-- Until the trust's Razorpay keys are set, the functions refuse and the app
-- hides the button, so nothing here is live yet.

-- A receipt paid through the gateway: card, UPI or netbanking, whichever the
-- member chose in Razorpay's checkout.
alter type public.payment_mode add value if not exists 'online';

create table public.online_payments (
  id                 uuid primary key default gen_random_uuid(),
  order_id           text not null unique,
  member_id          uuid not null references public.members (id),
  yojna_id           uuid not null references public.yojnas (id),
  closing_case_id    uuid references public.closing_cases (id) on delete set null,
  amount             numeric(12, 2) not null check (amount > 0),
  status             text not null default 'created'
                       check (status in ('created', 'paid')),
  gateway_payment_id text unique,
  payment_id         uuid references public.payments (id),
  created_at         timestamptz not null default now(),
  paid_at            timestamptz
);

create index online_payments_member_idx on public.online_payments (member_id);

-- Only the Edge Functions (service role) touch this table.
alter table public.online_payments enable row level security;
revoke all on public.online_payments from anon, authenticated;

-- What [p_member_id] owes for [p_closing_case_id] right now. Refuses when
-- nothing is owed, or when a payment for it is already waiting for approval.
create function public.online_payment_due(
  p_member_id uuid, p_closing_case_id uuid
) returns numeric
language plpgsql stable security definer set search_path = '' as $$
declare d record;
begin
  select * into d
    from public.member_dues md
   where md.member_id = p_member_id
     and md.closing_case_id = p_closing_case_id;
  if not found or d.due <= 0 then
    raise exception 'Nothing is owed for this closing.';
  end if;
  if d.pending > 0 then
    raise exception 'A payment for this closing is already waiting for approval.';
  end if;
  return d.due;
end $$;

-- Records a paid gateway order as a Paid receipt. Safe to call twice (the
-- browser and the webhook both do): the second call returns the first
-- receipt.
create function public.record_online_payment(
  p_order_id text, p_gateway_payment_id text
) returns table (payment_id uuid, receipt_no text)
language plpgsql security definer set search_path = '' as $$
#variable_conflict use_column
declare
  o public.online_payments;
  v_payment uuid;
  v_receipt text;
begin
  select * into o from public.online_payments op
   where op.order_id = p_order_id
   for update;
  if not found then
    raise exception 'Unknown order.';
  end if;

  if o.status = 'paid' then
    return query
    select p.id, p.receipt_no from public.payments p where p.id = o.payment_id;
    return;
  end if;

  insert into public.payments (
    receipt_no, member_id, yojna_id, amount, mode, status, kind, reference,
    source, closing_case_id, approved_at
  ) values (
    '', o.member_id, o.yojna_id, o.amount, 'online', 'paid',
    (case when o.closing_case_id is null then 'registration' else 'contribution' end)
      ::public.payment_kind,
    coalesce(p_gateway_payment_id, ''), 'member', o.closing_case_id, now()
  )
  returning id, payments.receipt_no into v_payment, v_receipt;

  update public.online_payments set
    status             = 'paid',
    gateway_payment_id = p_gateway_payment_id,
    payment_id         = v_payment,
    paid_at            = now()
  where id = o.id;

  return query select v_payment, v_receipt;
end $$;

revoke execute on function
  public.online_payment_due(uuid, uuid),
  public.record_online_payment(text, text)
from public, anon, authenticated;

grant execute on function
  public.online_payment_due(uuid, uuid),
  public.record_online_payment(text, text)
to service_role;
