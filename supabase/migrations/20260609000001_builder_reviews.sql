-- 20260609000001_builder_reviews.sql
-- S14: builder social proof. Tradies can already review builders (a review's
-- reviewee_id may be a builder profile id), but only trade_profiles carried the
-- denormalised rating columns + sync trigger — so builder ratings were phantom
-- (see _BuilderProfile, "rating/reviews are phantom for builders"). This mirrors
-- the trade machinery onto builder_profiles and folds builder recompute into the
-- existing reviews trigger so a tradie's review of a builder now sticks.

-- 1. Denormalised rating columns on builder_profiles (mirror trade_profiles from
--    20260604000001). Nullable average + zero-default count = "no reviews yet".
ALTER TABLE public.builder_profiles
  ADD COLUMN IF NOT EXISTS average_rating numeric(3,2),
  ADD COLUMN IF NOT EXISTS rating_count   int NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS builder_profiles_average_rating_idx
  ON public.builder_profiles (average_rating);

-- 2. Recompute one builder's average from reviews. SECURITY DEFINER so the
--    reviews trigger (fired by the reviewer, not the builder owner) can update
--    builder_profiles despite owner-only update RLS. Mirror of
--    recompute_trade_rating.
CREATE OR REPLACE FUNCTION public.recompute_builder_rating(p_builder_id uuid)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.builder_profiles bp
  SET average_rating = sub.avg_rating,
      rating_count   = sub.cnt
  FROM (
    SELECT round(avg(rating)::numeric, 2) AS avg_rating, count(*)::int AS cnt
    FROM public.reviews
    WHERE reviewee_id = p_builder_id
  ) sub
  WHERE bp.id = p_builder_id;
$$;

-- 3. Fold builder recompute into the existing reviews trigger function (keeps
--    the single trigger binding from 20260604000001). reviewee_id is either a
--    trade or a builder profile id; calling both recompute fns is safe — each is
--    a no-op when the id isn't a row in its table.
CREATE OR REPLACE FUNCTION public.reviews_sync_trade_rating()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (TG_OP = 'DELETE') THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    PERFORM public.recompute_builder_rating(OLD.reviewee_id);
    RETURN OLD;
  END IF;
  PERFORM public.recompute_trade_rating(NEW.reviewee_id);
  PERFORM public.recompute_builder_rating(NEW.reviewee_id);
  IF (TG_OP = 'UPDATE' AND OLD.reviewee_id <> NEW.reviewee_id) THEN
    PERFORM public.recompute_trade_rating(OLD.reviewee_id);
    PERFORM public.recompute_builder_rating(OLD.reviewee_id);
  END IF;
  RETURN NEW;
END;
$$;

-- 4. One-time backfill of existing builder reviewees (no-op for trade rows,
--    which were already backfilled by 20260604000001).
UPDATE public.builder_profiles bp
SET average_rating = sub.avg_rating,
    rating_count   = sub.cnt
FROM (
  SELECT reviewee_id,
         round(avg(rating)::numeric, 2) AS avg_rating,
         count(*)::int AS cnt
  FROM public.reviews
  GROUP BY reviewee_id
) sub
WHERE bp.id = sub.reviewee_id;
