# Jobdun — Supabase Edge Functions

Verification Edge Functions for the API-first verification flow.
See `docs/VERIFICATION_AUDIT.md` and `docs/VERIFICATION_USER_FLOWS.md`.

## Layout

```
supabase/functions/
  .env.example
  _shared/
    cors.ts
    supabase-client.ts        # service-role client + JWT helper + clientIp
    abn.ts                    # 11-digit format + checksum validator
    rate-limit.ts             # per-user 5/hr + per-IP 20/hr sliding window
    circuit-breaker.ts        # per-regulator breaker (open at 50% fail / 5 min)
    retry.ts                  # 3 tries, 1s/4s/16s + ±20% jitter
    regulators/
      types.ts                # LicenceAdapter interface + manualFallbackAllowed()
      index.ts                # state → adapter routing table
      nsw_adapter.ts          # NSW Fair Trading (STUB — see file header)
  verify-abn/index.ts         # ABR check (builders + trades)
  verify-licence/index.ts     # state-licence check (trades only); routes by state
```

## What's production vs stub (2026-05-25)

| Piece | Status |
|---|---|
| Migration `20260525000001_verifications.sql` | Production. RLS keyed off `user_roles.role = 'admin'`. |
| `verify-abn` Edge Function | Production. Needs `ABR_GUID` set in Supabase secrets. |
| `verify-licence` Edge Function | Production routing; calls the per-state adapter. |
| `_shared/regulators/nsw_adapter.ts` | **Stub.** Deterministic dev mode (last-5-digit suffix selects path). Real NSW Fair Trading scraper not yet pinned — see file header for finish steps. |
| VIC / QLD / SA / WA / TAS / ACT / NT adapters | Not implemented. Returns 501 `state_not_supported` until added. |

## Local development

```bash
# 1. Apply migrations to your local Supabase
supabase db push

# 2. Copy env
cp supabase/functions/.env.example supabase/functions/.env
# fill ABR_GUID + SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY

# 3. Serve functions
supabase functions serve --env-file supabase/functions/.env

# 4. Exercise (replace <jwt> with a Supabase session token)
curl -X POST http://localhost:54321/functions/v1/verify-abn \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"abn":"51824753556"}'

curl -X POST http://localhost:54321/functions/v1/verify-licence \
  -H "Authorization: Bearer <jwt>" \
  -H "Content-Type: application/json" \
  -d '{"licence_number":"EL-00000","state":"NSW","trade_class":"Electrician"}'
```

### NSW adapter dev shortcuts

Until the real NSW scraper is wired, licence numbers ending in:

| Suffix | Result |
|---|---|
| `00000` | verified (holder = "Test Tradie Pty Ltd", expires +2yr) |
| `11111` | failed / cancelled (no manual fallback) |
| `22222` | failed / suspended (no manual fallback) |
| `33333` | failed / not_found (manual fallback allowed) |
| `44444` | unknown / timeout → manual_review |
| anything else | unknown → manual_review |

These let the Flutter wizard be exercised end-to-end before the live scraper lands.

### ABR dev mode (no GUID needed)

Set `ABR_DEV_MODE=true` in `supabase/functions/.env` and `verify-abn` returns deterministic mocks instead of hitting the real ABR. Checksum validation is also skipped — any 11-digit string works.

| ABN suffix | Result |
|---|---|
| `11111` | failed / cancelled (no manual fallback) |
| `22222` | failed / suspended (no manual fallback) |
| `33333` | failed / unknown (manual fallback allowed) |
| anything else | verified (entity name = "Dev Test Business `<last-4>`") |

Example test ABNs (any 11 digits while dev mode is on):
- `12345678901` — verified, entity "Dev Test Business 8901"
- `99999911111` — cancelled
- `99999933333` — failed with manual upload allowed

**Important:** flip `ABR_DEV_MODE` off (or remove it) before deploying to production. The function will then require `ABR_GUID` and call the real ABR.

## Deploy

```bash
supabase functions deploy verify-abn
supabase functions deploy verify-licence

# secrets (production)
supabase secrets set ABR_GUID=<value> SENTRY_DSN=<value>
```

## Outstanding

- Real NSW Fair Trading scraper (`_shared/regulators/nsw_adapter.ts` — see file header).
- VIC + QLD adapters (Phase 7).
- `submit-application` + `publish-job` Edge Functions doing the cheap lookup (Phase 5).
- Nightly proactive re-check cron (Phase 6, replaces lazy-on-action).
- Per-user-local-time 7-day expiry push (Phase 6).
