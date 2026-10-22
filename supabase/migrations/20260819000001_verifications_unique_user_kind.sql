-- One verification row per (user, kind).
--
-- Both verify-* edge functions do select-then-insert with no DB backstop, so
-- concurrent taps could mint duplicate rows (P4/E1, 2026-08-18 live-bug
-- audit; pre-logged in docs/VERIFICATION_FLOW_AUDIT.md). Dedupe keeps the
-- most recently updated row per (user_id, kind).

WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY user_id, kind
           ORDER BY updated_at DESC, created_at DESC, id DESC
         ) AS rn
  FROM public.verifications
)
DELETE FROM public.verifications
WHERE id IN (SELECT id FROM ranked WHERE rn > 1);

ALTER TABLE public.verifications
  ADD CONSTRAINT verifications_user_kind_unique UNIQUE (user_id, kind);
