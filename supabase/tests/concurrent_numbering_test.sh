#!/usr/bin/env bash
# Phase 8: several admins saving at the same moment never get a duplicate or
# failed receipt / registration number.
#
# Runs WORKERS parallel psql sessions, each inserting PER_WORKER payments and
# members one statement (one transaction) at a time, then checks every number
# is distinct and the counters have no gaps.
#
# Writes rows and removes them afterwards. Use a disposable database (CI) or
# staging only, never production:
#   PGHOST=... PGUSER=... PGPASSWORD=... bash supabase/tests/concurrent_numbering_test.sh
set -euo pipefail

workers=${WORKERS:-4}
per_worker=${PER_WORKER:-250}
expected=$((workers * per_worker))
yojna=00000000-0000-0000-0000-0000000c0001
member=00000000-0000-0000-0000-0000000c0002

cleanup() {
  psql -v ON_ERROR_STOP=1 -q <<SQL
delete from public.payments where yojna_id = '$yojna';
delete from public.members where yojna_id = '$yojna';
delete from public.yojnas where id = '$yojna';
delete from public.counters where key like 'CONQ-%';
SQL
}

psql -v ON_ERROR_STOP=1 -q <<SQL
insert into public.yojnas (id, name, code) values ('$yojna', 'Concurrency check', 'CONQ');
insert into public.members (id, yojna_id, reg_no, name, primary_phone)
values ('$member', '$yojna', '', 'Concurrency check', '9000000000');
SQL
trap cleanup EXIT

batch=$(mktemp)
for _ in $(seq "$per_worker"); do
  echo "insert into public.payments (receipt_no, member_id, yojna_id, amount) values ('', '$member', '$yojna', 1);"
  echo "insert into public.members (yojna_id, reg_no, name, primary_phone) values ('$yojna', '', 'Concurrency check', '9' || lpad((random() * 999999999)::bigint::text, 9, '0'));"
done > "$batch"

pids=()
for _ in $(seq "$workers"); do
  psql -v ON_ERROR_STOP=1 -q -f "$batch" > /dev/null &
  pids+=($!)
done
for pid in "${pids[@]}"; do
  wait "$pid" || { echo "A parallel session failed"; exit 1; }
done
rm -f "$batch"

read -r receipts distinct_receipts receipt_span < <(psql -At -F ' ' -c "
  select count(*), count(distinct receipt_no),
         max(split_part(receipt_no, '-', 2)::int) - min(split_part(receipt_no, '-', 2)::int) + 1
    from public.payments where member_id = '$member'")
read -r regs distinct_regs reg_span < <(psql -At -F ' ' -c "
  select count(*), count(distinct reg_no),
         max(split_part(reg_no, '-', 3)::int) - min(split_part(reg_no, '-', 3)::int) + 1
    from public.members where yojna_id = '$yojna' and id <> '$member'")

fail=0
check() {
  if [ "$2" != "$3" ]; then echo "FAIL $1: got $2, expected $3"; fail=1; fi
}
check "receipts saved" "$receipts" "$expected"
check "distinct receipt numbers" "$distinct_receipts" "$expected"
check "receipt numbers without gaps" "$receipt_span" "$expected"
check "members saved" "$regs" "$expected"
check "distinct reg numbers" "$distinct_regs" "$expected"
check "reg numbers without gaps" "$reg_span" "$expected"

[ "$fail" = 0 ] || exit 1
echo "concurrent numbering checks passed ($workers sessions × $per_worker saves)"
