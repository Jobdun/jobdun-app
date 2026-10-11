#!/usr/bin/env bash
set -euo pipefail
# Invoked by run_admin_safety.sh against its own disposable container only.
test_container="$1"
[[ "$test_container" == jobdun-admin-safety-* ]]
[[ "$(docker inspect --format '{{.HostConfig.NetworkMode}}' "$test_container")" == none ]]
test_tmp="$(mktemp -d)"
trap 'rm -rf "$test_tmp"' EXIT
psql_local() { docker exec -i "$test_container" psql -X -U postgres -d postgres \
  -q -v ON_ERROR_STOP=1 -v VERBOSITY=verbose "$@"; }

expect_acl_denied() {
  local request_role="$1" statement="$2"
  if psql_local >"$test_tmp/acl.log" 2>&1 <<SQL
BEGIN;
SET LOCAL ROLE $request_role;
$statement
COMMIT;
SQL
  then echo 'FAIL: restricted RPC was callable'; return 1; fi
  rg -q '42501: permission denied for function' "$test_tmp/acl.log"
}
expect_acl_denied anon "SELECT public.admin_broadcast('Local title','Local body','all');"
expect_acl_denied anon "SELECT public.review_verification_document('d0000000-0000-0000-0000-000000000001','approved');"
expect_acl_denied authenticated "SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000001','b0000000-0000-0000-0000-000000000002','builder','trade','Synthetic reason');"
expect_acl_denied authenticated "SELECT public.admin_require_active('a0000000-0000-0000-0000-000000000001');"
echo 'PASS: fresh-session RPC privilege denials'

run_race() {
  local first_action="$1" second_action="$2" second_role="$3"
  # Reset only these synthetic fixtures; none of these scripts can reach a
  # network or the user's linked project, and every run uses a new container.
  psql_local >/dev/null <<'SQL'
SELECT set_config('request.jwt.claim.role', 'service_role', false);
UPDATE public.profiles SET user_status='active' WHERE id IN
  ('a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002');
UPDATE public.user_roles SET role='admin' WHERE user_id IN
  ('a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002');
SQL
  psql_local >"$test_tmp/first.log" 2>&1 <<SQL &
SET application_name='admin_safety_first';
BEGIN;
SELECT set_config('request.jwt.claim.role','service_role',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000001',true);
$first_action
SELECT pg_sleep(1);
COMMIT;
SQL
  local first_pid=$!
  local locked=false
  for attempt in {1..100}; do
    if [[ "$(psql_local -Atc "SELECT EXISTS(SELECT 1 FROM pg_locks l JOIN pg_stat_activity a ON a.pid=l.pid WHERE a.application_name='admin_safety_first' AND l.locktype='advisory' AND l.granted)")" == t ]]; then
      locked=true
      break
    fi
    sleep 0.02
  done
  [[ "$locked" == true ]] || { cat "$test_tmp/first.log"; return 1; }
  if psql_local >"$test_tmp/second.log" 2>&1 <<SQL
BEGIN;
SET LOCAL ROLE $second_role;
SELECT set_config('request.jwt.claim.role','$second_role',true);
SELECT set_config('request.jwt.claim.sub','a0000000-0000-0000-0000-000000000002',true);
$second_action
COMMIT;
SQL
  then
    echo 'FAIL: concurrent actor kept privileges after suspension/demotion'
    return 1
  fi
  wait "$first_pid"
  rg -q '42501: not_admin' "$test_tmp/second.log"
  [[ "$(psql_local -Atc "SELECT count(*) FROM public.user_roles r JOIN public.profiles p ON p.id=r.user_id WHERE role='admin' AND user_status='active'")" == 1 ]]
}

run_race \
  "SELECT public.admin_set_user_status('a0000000-0000-0000-0000-000000000002','suspended','Synthetic concurrency test');" \
  "SELECT public.admin_set_user_status('a0000000-0000-0000-0000-000000000001','suspended','Synthetic opposing request');" \
  authenticated
echo 'PASS: opposing concurrent suspensions preserve one active admin'

run_race \
  "SELECT public.admin_set_user_status('a0000000-0000-0000-0000-000000000002','suspended','Synthetic concurrency test');" \
  "SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000002','a0000000-0000-0000-0000-000000000001','builder','admin','Synthetic opposing request');" \
  service_role
echo 'PASS: concurrent suspension and role demotion preserve one active admin'

run_race \
  "SELECT public.admin_set_user_role('a0000000-0000-0000-0000-000000000001','a0000000-0000-0000-0000-000000000002','trade','admin','Synthetic concurrency test');" \
  "SELECT public.admin_set_user_status('a0000000-0000-0000-0000-000000000001','banned','Synthetic opposing request');" \
  authenticated
echo 'PASS: concurrent demotion removes stale moderation privileges'
