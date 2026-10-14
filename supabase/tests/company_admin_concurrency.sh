#!/usr/bin/env bash
set -euo pipefail
container="$1"
first_log="$(mktemp)"
second_log="$(mktemp)"
cleanup() { rm -f "$first_log" "$second_log"; }
trap cleanup EXIT
first_sql="BEGIN; SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true); UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000001'; SELECT pg_sleep(1); COMMIT;"
second_sql="BEGIN; SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true); UPDATE public.admin_staff SET active=false WHERE user_id='a0000000-0000-0000-0000-000000000002'; SELECT pg_sleep(1); COMMIT;"
docker exec -e PGPASSWORD=local-test-only "$container" psql -X -U postgres -d postgres -q -v ON_ERROR_STOP=1 -c "$first_sql" >"$first_log" 2>&1 &
first_pid=$!
docker exec -e PGPASSWORD=local-test-only "$container" psql -X -U postgres -d postgres -q -v ON_ERROR_STOP=1 -c "$second_sql" >"$second_log" 2>&1 &
second_pid=$!
first_status=0
second_status=0
wait "$first_pid" || first_status=$?
wait "$second_pid" || second_status=$?
active_owners="$(docker exec -e PGPASSWORD=local-test-only "$container" psql -X -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c "SELECT count(*) FROM public.admin_staff s JOIN public.profiles p ON p.id=s.user_id JOIN public.user_roles r ON r.user_id=s.user_id WHERE s.active AND s.staff_role='owner' AND p.user_status='active' AND r.role='admin'")"
if [[ "$active_owners" != 1 ]] || [[ "$first_status" -eq 0 && "$second_status" -eq 0 ]] || [[ "$first_status" -ne 0 && "$second_status" -ne 0 ]]; then
  cat "$first_log" "$second_log" >&2
  printf 'Expected exactly one owner deactivation to commit; active owners=%s, statuses=%s,%s\n' "$active_owners" "$first_status" "$second_status" >&2
  exit 1
fi
failed_log="$first_log"
if [[ "$second_status" -ne 0 ]]; then failed_log="$second_log"; fi
if ! rg -q 'last_active_owner' "$failed_log"; then
  cat "$failed_log" >&2
  printf 'Expected the losing transaction to fail at the last owner guard\n' >&2
  exit 1
fi
