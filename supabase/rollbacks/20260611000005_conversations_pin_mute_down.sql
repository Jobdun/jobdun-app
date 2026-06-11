-- DOWN for 20260611000005. Run manually only.
ALTER TABLE public.conversations
  DROP COLUMN IF EXISTS builder_pinned_at,
  DROP COLUMN IF EXISTS trade_pinned_at,
  DROP COLUMN IF EXISTS builder_muted_at,
  DROP COLUMN IF EXISTS trade_muted_at;
DROP INDEX IF EXISTS conversations_builder_pinned_idx;
DROP INDEX IF EXISTS conversations_trade_pinned_idx;
