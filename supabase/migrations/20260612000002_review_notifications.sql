-- 20260612000002_review_notifications.sql
-- Reviews feature (gap #1 closure): notify the reviewee when a review lands.
--
-- The review-submission UI ships with this migration; this adds the producer so
-- the loop is end-to-end: hired card → review sheet → reviews INSERT → this
-- trigger inserts a notification row → the central notifications_push_fanout
-- trigger (20260609000007) delivers the FCM push, gated by the user's 'reviews'
-- push preference (notification_category('review_received') = 'reviews').
--
-- Copy includes the rating but NOT the comment text (same privacy posture as
-- message notifications). data carries review_id (the client route resolver
-- keys on it for FCM payloads, which drop the type) + job_id + rating; tapping
-- routes to /reviews.
--
-- Schema (verified against 20260511000005_social.sql):
--   reviews(id, job_id, reviewer_id, reviewee_id, rating, comment, ...)
--   profiles(id, display_name, ...)
--
-- SECURITY DEFINER + search_path='' so the insert reaches the reviewee's
-- notifications row despite owner-only RLS, mirroring notify_on_new_message.

CREATE OR REPLACE FUNCTION public.notify_on_new_review()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  v_reviewer_name text;
BEGIN
  -- Defensive: never notify someone about their own review.
  IF NEW.reviewee_id = NEW.reviewer_id THEN
    RETURN NEW;
  END IF;

  SELECT p.display_name INTO v_reviewer_name
    FROM public.profiles p
   WHERE p.id = NEW.reviewer_id;

  INSERT INTO public.notifications (user_id, type, title, body, data)
  VALUES (
    NEW.reviewee_id,
    'review_received',
    'New review',
    COALESCE(NULLIF(v_reviewer_name, ''), 'Someone')
      || ' rated you ' || NEW.rating || '/5',
    jsonb_build_object(
      'review_id', NEW.id,
      'job_id',    NEW.job_id,
      'rating',    NEW.rating
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS notify_on_new_review_trg ON public.reviews;
CREATE TRIGGER notify_on_new_review_trg
  AFTER INSERT ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.notify_on_new_review();
