#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
test_container="jobdun-staff-chat-$$"
cleanup() { docker rm -f "$test_container" >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run --detach --name "$test_container" --network none --env POSTGRES_PASSWORD=local-test-only public.ecr.aws/supabase/postgres:17.6.1.111 >/dev/null
for attempt in {1..60}; do
 if [[ "$(docker inspect --format '{{.State.Health.Status}}' "$test_container" 2>/dev/null)" == healthy ]]; then break; fi
 sleep 1
done
sql() { docker exec -e PGPASSWORD=local-test-only -i "$test_container" psql -X -U "${2:-postgres}" -d postgres -q -v ON_ERROR_STOP=1 < "$repo_root/$1"; }
sql supabase/tests/admin_safety_bootstrap.sql supabase_admin >/dev/null
sql supabase/tests/company_admin_pre_migration_schema.sql supabase_admin >/dev/null
# Reconstruct the reviewed safety migration; the schema snapshot carries its
# definitions but not all effective grants under fresh database defaults.
sql supabase/migrations/20260527000001_verification_documents_admin_review.sql >/dev/null
docker exec -e PGPASSWORD=local-test-only "$test_container" psql -X -U postgres -d postgres -q -v ON_ERROR_STOP=1 -c "DROP POLICY verification_documents_admin_update ON public.verification_documents" >/dev/null
sql supabase/rollbacks/20261011000001_admin_safety_down.sql >/dev/null
sql supabase/migrations/20261007000001_admin_user_management.sql >/dev/null
sql supabase/tests/admin_safety_fixture.sql >/dev/null
sql supabase/migrations/20261011000001_admin_safety.sql >/dev/null
if [[ "${1:-}" != --baseline ]]; then
 sql supabase/tests/company_admin_baseline.sql
 sql supabase/migrations/20261014000001_company_admin.sql
fi
docker exec -e PGPASSWORD=local-test-only "$test_container" psql -X -U supabase_admin -d postgres -q -v ON_ERROR_STOP=1 -c "ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS email_confirmed_at timestamptz" >/dev/null
sql supabase/migrations/20261021000001_staff_chat.sql
sql supabase/tests/staff_chat.sql
sql supabase/tests/staff_chat_files_storage_bootstrap.sql supabase_admin
sql supabase/migrations/20261023000001_staff_chat_attachments.sql
sql supabase/tests/staff_chat_attachments.sql
sql supabase/rollbacks/20261023000001_staff_chat_attachments_down.sql
sql supabase/tests/staff_chat_files_rollback_check.sql
sql supabase/tests/staff_chat.sql
sql supabase/migrations/20261023000001_staff_chat_attachments.sql
sql supabase/tests/staff_chat_attachments.sql
