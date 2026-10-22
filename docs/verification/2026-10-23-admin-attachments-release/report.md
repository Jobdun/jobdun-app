# Production staff attachment backend — 23 October 2026

User authorized pushing the admin updates to main and updating the shared
production backend. Existing accounts and chat history are retained; no local
synthetic accounts, threads or files are imported.

- Shared production project: `zethpanvkfyijislxesn`.
- Source implementation commit: `494f65d`.
- Linked dry run selected only `20261023000001_staff_chat_attachments.sql`.
- That migration was applied successfully; linked migration history now agrees
  through 23 October. Older already-applied migration source files were added to
  Git to reconcile repository history, not reapplied to the database.
- `admin-chat-files` Edge release 1 is ACTIVE. Gateway JWT verification is disabled
  for asymmetric-token compatibility; the handler independently verifies every
  bearer with Auth.getUser and SQL enforces fresh staff/MFA/participation.
- Public schema snapshot was refreshed directly from the deployed database.
- A protected, mode600 backup of public+storage schema and public table data was
  completed before migration. Backup hashes/sizes are in backup-manifest.json;
  actual customer data remains outside Git. This is not a full Auth/file backup.

Validation: 9 Deno tests passed; isolated SQL apply/security/retry/cleanup/privacy,
rollback and reapply passed against a fixed pre-company baseline. That fixed
fixture now also backs the reproducible full local setup, avoiding collisions
with the updated production schema snapshot. No live staff messages were sent.

The private bucket is service-only; images/PDF/text are capped at 3 MiB, one per
message. Metadata URLs remain private; finalized files share message retention.
Rollback the website first and keep this additive database schema in place.
The SQL rollback refuses to remove linked attachment history and preserves
retained Storage privacy. A later destructive rollback needs export/retention
planning.

Hosted read-only transport checks passed: anonymous GET401, authorized access to
a missing/private file403, malformed upload400. No file, thread or message was
created by these production checks. Public schema drift check passed against a
second fresh remote dump.
