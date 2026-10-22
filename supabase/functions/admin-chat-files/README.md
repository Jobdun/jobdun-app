# Private staff attachments

Production deployment on23 October2026 is recorded in
`docs/verification/2026-10-23-admin-attachments-release/report.md`. Future releases
must apply the reviewed SQL migration before the Edge function and web changes. The Edge runtime alone
holds `SUPABASE_SERVICE_ROLE_KEY`. The browser/Next server only forwards the
current user's bearer token. Auth verifies that token through `getUser`; SQL
checks fresh work email, active company staff/profile, membership and MFA
policy.

POST multipart fields are exactly `threadId`, `clientTag`, `file`. The response
contains only `{data:{id,name,mime,size}}`. One nonempty file, at most 3 MiB,
with matching MIME/extension is permitted: JPEG (.jpg/.jpeg), PNG, static WebP,
PDF, or UTF-8 plain text (.txt). PNG chunk CRC, image container/frame headers
and bounded dimensions (8192 per side, 32 megapixels), PDF header/EOF and text
encoding are checked. PDF JavaScript/launch/embedded-file/open-action markers
and active HTML/SVG text are rejected. Validation is a strict format/header
gate, **not** a malware scanner or a promise of full document/image decoder
validation. There is no antivirus scanning claim. PDFs/text always download;
only images can render inline. GET rechecks current authorization and returns
private/no-store, nosniff and sandbox headers. Neither metadata nor message JSON
stores a URL.

The service-only Storage bucket has a restrictive authenticated/anonymous policy
that also denies access if another broad permissive policy exists. Client RPCs
cannot create trusted attachments or link unvalidated/expired/cross-thread or
another owner's uploads. A client tag is bound to the actor, thread, original
name, MIME, size and SHA-256. Identical retries reuse the upload/message;
changed payloads conflict. Message linking and finalization share a database
transaction.

Reservations expire after one hour; limits are 10 outstanding uploads and 20 new
reservations per minute per actor. Every authorized POST runs bounded cleanup of
up to 10 expired reservations. Cleanup locks rows and makes them unsendable
before Storage deletion. Failures retain a retryable cleaning state; successful
deletion leaves a cleaned retry tombstone, releasing pending quota. Tombstones
remain for 24 hours and receive a second Storage deletion before row removal,
catching late uploads racing expiry. No traffic means cleanup waits until the
next authorized upload; operators may run the same `cleanup_claim` -> Storage
removal -> `cleanup_done` sequence in a scheduled trusted worker if prompt
deletion is required. Do not call `cleanup_done` after failed deletion.

Finalized metadata/files are retained indefinitely with message history. Cleanup
explicitly excludes finalized or message-linked files. There is no user deletion
or automatic retention policy in v1. Rollback refuses to drop the attachment
schema while any linked message exists; the private bucket is retained for
operator-managed export/retention. Roll back web usage before schema removal.

Local checks:

```sh
~/.deno/bin/deno test supabase/functions/admin-chat-files
~/.deno/bin/deno lint supabase/functions/admin-chat-files
~/.deno/bin/deno check supabase/functions/admin-chat-files/index.ts
bash supabase/tests/run_staff_chat_attachments.sh
```

The SQL runner uses a disposable Docker database with no external network and
checks legacy text behavior, attachment trust/access/retries, hydrated history,
cleanup and migration rollback/reapply. The separate full local Supabase HTTP
runner exercises real Auth, Storage and the Edge runtime with synthetic staff.
