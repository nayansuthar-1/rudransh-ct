-- IMPLEMENTATION_PLAN §7, the rest of it: recorded consent, and a way to give a
-- member their data or erase it on request (DPDP Act 2023).
--
-- Erasure here means **anonymising**, not deleting. The trust's receipts are
-- financial records it must keep, and a member's contributions are what pay
-- other families' claims — removing the rows would corrupt every closing they
-- ever paid into. So the money stays and the person is removed from it.

-- ---------------------------------------------------------------------------
-- Consent
-- ---------------------------------------------------------------------------

-- Nullable on purpose: members enrolled before this existed never gave it, and
-- pretending otherwise by back-dating would be worse than an honest gap.
alter table public.members
  add column consent_at   timestamptz,
  add column consent_note text not null default '';

comment on column public.members.consent_at is
  'When the member agreed to the trust holding their details. Null for records '
  'created before consent was recorded (IMPLEMENTATION_PLAN §7).';

-- ---------------------------------------------------------------------------
-- Give a member their data
-- ---------------------------------------------------------------------------

-- Owner only: the export carries the full Aadhaar, which is the point — it is
-- the member's own data being handed back to them.
create function public.export_member_data(p_member_id uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  m      record;
  result jsonb;
begin
  perform public.require_owner();

  select * into m from public.members where id = p_member_id;
  if not found then
    raise exception 'Member not found.';
  end if;

  select jsonb_build_object(
    'exported_at', now(),
    'member',
      (to_jsonb(m) - 'aadhaar' - 'aadhaar_enc' - 'aadhaar_last4' - 'search_text')
        || jsonb_build_object('aadhaar', public.member_aadhaar(m.id)),
    'yojna', (
      select jsonb_build_object('name', y.name, 'code', y.code,
                                'contribution_amount', y.contribution_amount)
        from public.yojnas y where y.id = m.yojna_id
    ),
    'agent', (
      select jsonb_build_object('name', a.name, 'code', a.code)
        from public.agents a where a.id = m.agent_id
    ),
    'payments', coalesce((
      select jsonb_agg(to_jsonb(p) - 'search_text' order by p.date, p.receipt_no)
        from public.payments p where p.member_id = m.id
    ), '[]'::jsonb),
    'closing_case', (
      select to_jsonb(c) from public.closing_cases c where c.member_id = m.id
    ),
    'change_requests', coalesce((
      select jsonb_agg(to_jsonb(r) order by r.created_at)
        from public.change_requests r where r.member_id = m.id
    ), '[]'::jsonb),
    'death_reports', coalesce((
      select jsonb_agg(to_jsonb(q) order by q.created_at)
        from public.closing_requests q where q.member_id = m.id
    ), '[]'::jsonb)
  ) into result;

  return result;
end $$;

-- ---------------------------------------------------------------------------
-- Erase a member on request
-- ---------------------------------------------------------------------------

-- Keeps every receipt and closing exactly as it is, and empties the person out
-- of the member row. Irreversible: the details are overwritten, not hidden.
create function public.erase_member_data(p_member_id uuid, p_reason text)
returns void
language plpgsql security definer set search_path = '' as $$
declare
  v_reason text := trim(coalesce(p_reason, ''));
  v_reg    text;
begin
  perform public.require_owner();
  if v_reason = '' then
    raise exception 'Give a reason.';
  end if;

  select reg_no into v_reg from public.members where id = p_member_id;
  if not found then
    raise exception 'Member not found.';
  end if;

  -- `aadhaar` stays out of the SET list: the encrypt trigger fires on that
  -- column and its "empty means unchanged" branch would restore the
  -- ciphertext this statement is trying to remove.
  update public.members set
    name                   = 'Erased member',
    father_or_husband_name = '',
    jati                   = '',
    gotra                  = '',
    dob                    = null,
    waris_name             = '',
    waris_relation         = '',
    -- The column demands ten digits, so it cannot simply be emptied.
    primary_phone          = '0000000000',
    alt_phone              = '',
    village                = '',
    tehsil                 = '',
    district               = '',
    state                  = '',
    pincode                = '',
    aadhaar_enc            = null,
    aadhaar_last4          = '',
    consent_note           = '',
    status                 = 'inactive',
    review_note            = 'Erased on request: ' || v_reason
  where id = p_member_id;

  -- Nothing addressed to them should survive either.
  delete from public.lookup_attempts where reg_no = v_reg;
end $$;

-- ---------------------------------------------------------------------------
-- Access
-- ---------------------------------------------------------------------------

revoke all on function
  public.export_member_data(uuid),
  public.erase_member_data(uuid, text)
from public, anon;

grant execute on function
  public.export_member_data(uuid),
  public.erase_member_data(uuid, text)
to authenticated;
