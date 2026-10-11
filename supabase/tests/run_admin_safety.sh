#!/usr/bin/env bash
set -euo pipefail
# No linked Supabase project, environment credentials, ports or external network.
# The only writes target a newly created disposable Docker container.
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_container="jobdun-admin-safety-$$"
test_image="${ADMIN_TEST_IMAGE:-public.ecr.aws/supabase/postgres:17.6.1.111}"
test_mode="${1:-}"
cleanup() {
  local result=$?
  if (( result != 0 )); then docker logs --tail 35 "$test_container" 2>&1; fi
  docker rm -f "$test_container" >/dev/null 2>&1 || true
}
trap cleanup EXIT
docker run --detach --name "$test_container" --network none \
  --env POSTGRES_PASSWORD=local-test-only "$test_image" >/dev/null
for attempt in {1..60}; do
  if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$test_container" 2>/dev/null)" == healthy ]]; then break; fi
  sleep 1
done
sql() { docker exec -e PGPASSWORD=local-test-only -i "$test_container" \
  psql -X -U "${2:-postgres}" -d postgres -q -v ON_ERROR_STOP=1 < "$repo_root/$1"; }
query() { docker exec -e PGPASSWORD=local-test-only "$test_container" \
  psql -X -U postgres -d postgres -qAt -v ON_ERROR_STOP=1 -c "$1"; }
sql supabase/tests/admin_safety_bootstrap.sql supabase_admin
sql supabase/schema.sql supabase_admin
# Public-only schema snapshot excludes managed storage policies.
sql supabase/migrations/20260527000001_verification_documents_admin_review.sql
# A refreshed snapshot already contains the safety migration. Restore the
# reviewed pre-safety baseline in this disposable database before testing the
# forward migration; --baseline must still expose the original defects.
if [[ "$(query "SELECT to_regprocedure('public.admin_require_active(uuid)') IS NOT NULL")" == t ]]; then
  # The legacy storage bootstrap also recreates this removed public policy;
  # the rollback must be the sole operation that restores it to the baseline.
  query 'DROP POLICY verification_documents_admin_update ON public.verification_documents;'
  sql supabase/rollbacks/20261011000001_admin_safety_down.sql
fi
sql supabase/migrations/20261007000001_admin_user_management.sql
sql supabase/tests/admin_safety_fixture.sql
if [[ "$test_mode" != --baseline ]]; then
  sql supabase/migrations/20261011000001_admin_safety.sql
fi
sql supabase/tests/admin_safety.sql
if [[ "$test_mode" != --baseline ]]; then
  sql supabase/rollbacks/20261011000001_admin_safety_down.sql
  sql supabase/migrations/20261011000001_admin_safety.sql
  sql supabase/tests/admin_safety.sql
  bash "$repo_root/supabase/tests/admin_safety_concurrency.sh" "$test_container"
fi
