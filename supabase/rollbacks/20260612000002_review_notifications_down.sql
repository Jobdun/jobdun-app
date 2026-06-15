-- Rollback for 20260612000002_review_notifications.sql
DROP TRIGGER IF EXISTS notify_on_new_review_trg ON public.reviews;
DROP FUNCTION IF EXISTS public.notify_on_new_review();
