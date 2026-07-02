# B1 — Lock down `push-send` (caller authorization) · `API5` + `API2` + `API6`

**Problem:** `push-send` trusts any caller holding the public anon key, so anyone can push arbitrary notifications to any/all users. Fix = a **shared internal secret** that only the DB fan-out knows, verified inside the function. Also removes the hardcoded anon JWT (F7).

**Risk:** medium — touches the live notification path. Test with a real notification after wiring. **Not applied.**

## Step 1 — provision the secret (once)

```bash
# generate a strong token
openssl rand -hex 32
# store it as an Edge Function secret (server-only, never in the client)
supabase secrets set PUSH_INTERNAL_TOKEN=<the-hex-token>
# also store it where the DB fan-out can read it (Supabase Vault):
#   insert into vault.secrets (name, secret) values ('push_internal_token', '<the-hex-token>');
```

## Step 2 — verify the token inside the function

`supabase/functions/push-send/index.ts` — at the very top of the handler, before any work:

```ts
// --- B1: internal-caller authorization -------------------------------------
const INTERNAL = Deno.env.get("PUSH_INTERNAL_TOKEN");
const presented = req.headers.get("x-internal-token");
if (!INTERNAL || presented !== INTERNAL) {
  return jsonResponse({ error: "unauthorized" }, 401);
}
// ---------------------------------------------------------------------------
```

## Step 3 — stop using the anon key as the trigger credential

`supabase/config.toml` — make the function rely solely on the shared secret (so the anon JWT is not even a partial gate):

```toml
[functions.push-send]
verify_jwt = false
```

## Step 4 — send the secret from the DB fan-out (removes F7's hardcoded JWT)

In `notifications_push_fanout()` (source migration `20260609000005` / `…0007`, net schema `supabase/schema.sql:864-867`), replace the hardcoded anon-key `Authorization` header with the vault-read internal token:

```sql
-- read once from Vault instead of hardcoding a JWT
v_token text := (select decrypted_secret from vault.decrypted_secrets where name = 'push_internal_token');
-- ...
perform net.http_post(
  url     := v_func_url,
  headers := jsonb_build_object(
    'Content-Type',     'application/json',
    'x-internal-token', v_token           -- was: 'Authorization', 'Bearer <hardcoded anon jwt>'
  ),
  body    := v_payload
);
```

## Verify

```bash
# anon call must now be rejected:
curl -s -X POST "$SUPABASE_URL/functions/v1/push-send" \
  -H "Authorization: Bearer $SUPABASE_ANON_KEY" \
  -H "Content-Type: application/json" \
  -d '{"user_ids":["<any>"],"title":"x","body":"y"}'
# expect: {"error":"unauthorized"}  (401)

# a real in-app action (e.g. new message) must still deliver its push.
```

**Rollback:** revert the `index.ts` block, remove the `[functions.push-send]` toml block, restore the previous `notifications_push_fanout()` body. (Rotate `PUSH_INTERNAL_TOKEN` if it was ever exposed.)
