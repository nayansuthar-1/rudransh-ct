-- Add age_slabs column to public.yojnas to support age-based registration fee
-- and per-event contribution slabs.

alter table public.yojnas
  add column if not exists age_slabs jsonb not null default '[]'::jsonb;

-- Update agent_yojnas to include age_slabs so agent apps can access slabs
drop function if exists public.agent_yojnas();

create function public.agent_yojnas()
returns table (
  id uuid, name text, code text, description text,
  registration_fee numeric, start_date date, short_name text,
  age_slabs jsonb
)
language plpgsql stable security definer set search_path = '' as $$
#variable_conflict use_column
declare a uuid := public.require_agent();
begin
  return query
  select y.id, y.name, y.code, y.description,
         y.registration_fee, y.start_date, y.short_name,
         y.age_slabs
    from public.yojnas y
    join public.agents ag on ag.id = a
   where y.is_active
     and (cardinality(ag.yojna_ids) = 0 or y.id = any (ag.yojna_ids))
   order by y.name;
 end $$;

revoke all on function public.agent_yojnas() from public, anon;
grant execute on function public.agent_yojnas() to authenticated;
