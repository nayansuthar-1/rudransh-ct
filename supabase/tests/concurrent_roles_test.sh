#!/usr/bin/env bash
# Phase 17: two agents and an admin working at the same moment never produce a
# duplicate registration or receipt number.
#
# concurrent_numbering_test.sh already hammers the counter as the table owner.
# This one goes through the paths the app actually uses, which are different
# code and different privileges:
#
#   * agents call `agent_add_member` and `agent_record_payment` as
#     `authenticated`, with their own JWT claim, through security-definer
#     functions that force `status = 'pending'` and `agent_id = my_agent_id()`
#   * an admin inserts members and payments straight into the tables
#   * the admin then approves every pending member at once, which is when an
#     agent's member is given its registration number
#
# Writes rows and removes them afterwards. Use a disposable database (CI) or
# staging only, never production:
#   PGHOST=... PGUSER=... PGPASSWORD=... bash supabase/tests/concurrent_roles_test.sh
set -euo pipefail

per_worker=${PER_WORKER:-120}

yojna=00000000-0000-0000-0000-0000000e0001
agent_a=00000000-0000-0000-0000-0000000e0011
agent_b=00000000-0000-0000-0000-0000000e0012
user_a=00000000-0000-0000-0000-00000000e003
user_b=00000000-0000-0000-0000-00000000e004
user_admin=00000000-0000-0000-0000-00000000e005
seed_a=00000000-0000-0000-0000-0000000e0021
seed_b=00000000-0000-0000-0000-0000000e0022

cleanup() {
  psql -v ON_ERROR_STOP=1 -q <<SQL
delete from public.payments where yojna_id = '$yojna';
delete from public.members where yojna_id = '$yojna';
delete from public.profiles where user_id in ('$user_a', '$user_b', '$user_admin');
delete from public.agents where id in ('$agent_a', '$agent_b');
delete from public.yojnas where id = '$yojna';
delete from auth.users where id in ('$user_a', '$user_b', '$user_admin');
delete from public.counters where key like 'ROLQ-%';
SQL
}

psql -v ON_ERROR_STOP=1 -q <<SQL
insert into public.yojnas (id, name, code, contribution_amount, registration_fee)
values ('$yojna', 'Role concurrency check', 'ROLQ', 100, 50);

insert into public.agents (id, code, name, commission_percent) values
  ('$agent_a', '', 'Concurrent Agent A', 5),
  ('$agent_b', '', 'Concurrent Agent B', 5);

insert into auth.users (id, email) values
  ('$user_a', 'conc.a@test.local'),
  ('$user_b', 'conc.b@test.local'),
  ('$user_admin', 'conc.admin@test.local');

insert into public.profiles (user_id, role, agent_id) values
  ('$user_a', 'agent', '$agent_a'),
  ('$user_b', 'agent', '$agent_b'),
  ('$user_admin', 'owner', null);

-- Each agent needs an approved member of their own to collect against: a
-- pending one may only be charged the registration fee, and an agent cannot
-- touch another agent's member.
insert into public.members (id, yojna_id, reg_no, name, primary_phone, agent_id, status) values
  ('$seed_a', '$yojna', '', 'Concurrency seed A', '9000000001', '$agent_a', 'active'),
  ('$seed_b', '$yojna', '', 'Concurrency seed B', '9000000002', '$agent_b', 'active');
SQL
trap cleanup EXIT

# One agent's batch: a new member, then a registration fee for it. Both go
# through the RPCs, so the run also proves the functions are safe in parallel.
agent_batch() {
  local uid=$1 seed=$2 out=$3
  {
    echo "set role authenticated;"
    echo "select set_config('request.jwt.claim.sub', '$uid', false);"
    for i in $(seq "$per_worker"); do
      echo "select public.agent_add_member(jsonb_build_object("
      echo "  'yojna_id', '$yojna', 'name', 'Conc member $uid-$i',"
      echo "  'primary_phone', '9' || lpad((random() * 999999999)::bigint::text, 9, '0'),"
      echo "  'contribution_amount', 100));"
      echo "select public.agent_record_payment(jsonb_build_object("
      echo "  'member_id', '$seed', 'amount', 100, 'kind', 'contribution'));"
    done
  } > "$out"
}

admin_batch=$(mktemp)
{
  for _ in $(seq "$per_worker"); do
    echo "insert into public.members (yojna_id, reg_no, name, primary_phone) values ('$yojna', '', 'Conc office', '9' || lpad((random() * 999999999)::bigint::text, 9, '0'));"
    echo "insert into public.payments (receipt_no, member_id, yojna_id, amount) values ('', '$seed_a', '$yojna', 100);"
  done
} > "$admin_batch"

batch_a=$(mktemp); agent_batch "$user_a" "$seed_a" "$batch_a"
batch_b=$(mktemp); agent_batch "$user_b" "$seed_b" "$batch_b"

pids=()
psql -v ON_ERROR_STOP=1 -q -f "$batch_a" > /dev/null & pids+=($!)
psql -v ON_ERROR_STOP=1 -q -f "$batch_b" > /dev/null & pids+=($!)
psql -v ON_ERROR_STOP=1 -q -f "$admin_batch" > /dev/null & pids+=($!)
for pid in "${pids[@]}"; do
  wait "$pid" || { echo "A parallel session failed"; exit 1; }
done
rm -f "$batch_a" "$batch_b" "$admin_batch"

# Approving hands each agent's pending member its registration number. Doing
# it in one statement is the worst case for the counter: every row fires the
# trigger inside a single transaction.
psql -v ON_ERROR_STOP=1 -q > /dev/null <<SQL
set role authenticated;
select set_config('request.jwt.claim.sub', '$user_admin', false);
select public.approve_member(id) from public.members
 where yojna_id = '$yojna' and status = 'pending';
SQL

# Agents make 1 member + 1 receipt each; the admin the same. Plus the two seed
# members, which already have numbers.
agent_rows=$((per_worker * 2))
expected_members=$((agent_rows + per_worker + 2))
expected_receipts=$((agent_rows + per_worker))

# `tr -d '\r'`: psql writes CRLF on Windows, and a stray carriage return makes
# every string comparison below fail while printing identical-looking values.
query() { psql -At -F ' ' -c "$1" | tr -d '\r'; }

read -r members distinct_regs blank_regs < <(query "
  select count(*), count(distinct reg_no), count(*) filter (where coalesce(reg_no, '') = '')
    from public.members where yojna_id = '$yojna'")
read -r receipts distinct_receipts receipt_span < <(query "
  select count(*), count(distinct receipt_no),
         max(split_part(receipt_no, '-', 2)::int) - min(split_part(receipt_no, '-', 2)::int) + 1
    from public.payments where yojna_id = '$yojna'")
pending=$(query "
  select count(*) from public.members
   where yojna_id = '$yojna' and status = 'pending'")

fail=0
check() {
  if [ "$2" != "$3" ]; then echo "FAIL $1: got $2, expected $3"; fail=1; fi
}
check "members saved" "$members" "$expected_members"
check "distinct reg numbers" "$distinct_regs" "$expected_members"
check "members left without a number" "$blank_regs" "0"
check "members left pending" "$pending" "0"
check "receipts saved" "$receipts" "$expected_receipts"
check "distinct receipt numbers" "$distinct_receipts" "$expected_receipts"
check "receipt numbers without gaps" "$receipt_span" "$expected_receipts"

[ "$fail" = 0 ] || exit 1
echo "concurrent role checks passed (2 agents + 1 admin × $per_worker saves each)"
