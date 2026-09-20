-- Membership certificate, part 2 (docs/MEMBERSHIP_CERTIFICATE_PLAN.md).
--
-- The certificate prints `योजना प्रारंभ`, the day the scheme actually opened.
-- That was being taken from `yojnas.created_at`, which is the day the record
-- was typed into the app — a different date, and wrong on the printed sheet.
-- Schemes now carry their own start date.

alter table public.yojnas add column start_date date;

-- ---------------------------------------------------------------------------
-- Agent functions
-- ---------------------------------------------------------------------------

-- Agents print certificates too, so `agent_yojnas` has to hand back the two
-- fields the sheet needs: the start date, and the description, which is the
-- `नोंध` payout line. Adding output columns changes the return type, so the
-- function is dropped and its grants given again below.
drop function if exists public.agent_yojnas();

create function public.agent_yojnas()
returns table (
  id uuid, name text, code text, description text,
  contribution_amount numeric, registration_fee numeric, start_date date
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select y.id, y.name, y.code, y.description,
         y.contribution_amount, y.registration_fee, y.start_date
    from public.yojnas y
    join public.agents ag on ag.id = a
   where y.is_active
     and (cardinality(ag.yojna_ids) = 0 or y.id = any (ag.yojna_ids))
   order by y.name;
end $$;

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

revoke all on function public.agent_yojnas() from public, anon;
grant execute on function public.agent_yojnas() to authenticated;
