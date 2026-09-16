#!/usr/bin/env bash
# Restore a nightly backup into a database that already has the migrations
# applied (normally staging, or a fresh project after `supabase db push`).
#
#   scripts/restore_backup.sh <backup.tar.age | backup.tar> <target-db-url> [age-identity-file]
#
# Replaces ALL app data in the target. Download a backup first with:
#   aws s3 cp s3://$R2_BUCKET/daily/rudransh-YYYY-MM-DD.tar.age . \
#     --endpoint-url https://$R2_ACCOUNT_ID.r2.cloudflarestorage.com
set -euo pipefail

backup=${1:?backup file}
target=${2:?target database URL}
identity=${3:-}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

case "$backup" in
  *.age)
    : "${identity:?age identity file is required for an encrypted backup}"
    age -d -i "$identity" -o "$work/backup.tar" "$backup"
    ;;
  *) cp "$backup" "$work/backup.tar" ;;
esac
tar -C "$work" -xf "$work/backup.tar"

echo "Target: ${target##*@}"
psql "$target" -Atc "select 'members now: ' || count(*) from public.members"
if [ "${RESTORE_YES:-}" != "1" ]; then
  read -r -p "Replace all app data in this database? Type RESTORE: " answer
  [ "$answer" = "RESTORE" ] || { echo "Aborted."; exit 1; }
fi

# Wipe app data; the schema stays as the migrations created it.
psql "$target" -v ON_ERROR_STOP=1 -q <<'SQL'
truncate public.audit_log, public.payments, public.closing_cases, public.members,
         public.agents, public.yojnas, public.counters, public.admins
  restart identity cascade;
SQL

# Auth users first, because admins reference them. Dumped with ON CONFLICT DO NOTHING.
pg_restore --data-only --no-owner --no-privileges -d "$target" "$work/auth_users.dump"

# App data with triggers off, so audit rows and numbering are not re-run.
PGOPTIONS='-c session_replication_role=replica' \
  pg_restore --data-only --no-owner --no-privileges --schema=public \
  --exit-on-error -d "$target" "$work/public.dump"

psql "$target" -v ON_ERROR_STOP=1 -At <<'SQL'
select 'yojnas: '   || count(*) from public.yojnas;
select 'members: '  || count(*) from public.members;
select 'agents: '   || count(*) from public.agents;
select 'payments: ' || count(*) || ', paid total: '
       || coalesce(sum(amount) filter (where status = 'paid'), 0) from public.payments;
select 'closing cases: ' || count(*) from public.closing_cases;
select 'admins: '   || count(*) from public.admins;
select 'counters: ' || string_agg(key || '=' || value, ', ' order by key) from public.counters;
SQL
echo "Restore complete. Compare these counts with the source before signing off."
