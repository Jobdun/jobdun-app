#!/usr/bin/env bash
# Retry only infrastructure downloads; never retry or skip the SQL assertions.
set -euo pipefail
digest=dda62da900896d4a8f1cf687cd9912c8d3ea4ad442c9273c27848fa8f42da6cc
for registry in ghcr.io/supabase/postgres public.ecr.aws/supabase/postgres; do
  test_image="$registry:17.6.1.111@sha256:$digest"
  for attempt in 1 2 3; do
    if docker pull "$test_image"; then
      if [[ -n "${GITHUB_ENV:-}" ]]; then
        printf 'ADMIN_TEST_IMAGE=%s\n' "$test_image" >> "$GITHUB_ENV"
      fi
      exit 0
    fi
    sleep "$((attempt * 5))"
  done
done
echo 'Unable to download the pinned SQL test image from either official mirror.' >&2
exit 1
