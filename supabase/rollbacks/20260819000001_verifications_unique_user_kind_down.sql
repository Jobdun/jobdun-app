-- Rollback for 20260819000001_verifications_unique_user_kind.sql.
-- The dedupe DELETE is not reversible; this only drops the constraint.
ALTER TABLE public.verifications
  DROP CONSTRAINT IF EXISTS verifications_user_kind_unique;
