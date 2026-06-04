-- 20260604000003_get_inbox_security_definer.sql
--
-- Fix: inbox showed "Unknown" for the counterparty in the app (but the correct
-- name in the SQL editor). Cause: get_inbox (20260603000001) was SECURITY
-- INVOKER and LEFT JOINs public.profiles for the OTHER participant. Under the
-- profiles_select_own RLS policy (auth.uid() = id) an authenticated caller can
-- only read their own profile row, so other.display_name resolved to NULL.
-- service_role (SQL editor) bypasses RLS, which is why it looked fine there.
--
-- Re-create as SECURITY DEFINER so the counterparty-name join is not blocked by
-- RLS, with an explicit `auth.uid() = p_user` guard so a caller can still only
-- read THEIR OWN inbox (DEFINER otherwise bypasses the conversations RLS too).
--
-- Reversibility: re-run 20260603000001's definition to revert to INVOKER.

CREATE OR REPLACE FUNCTION public.get_inbox(p_user uuid)
RETURNS TABLE (
  id                     uuid,
  job_id                 uuid,
  builder_id             uuid,
  trade_id               uuid,
  last_message_at        timestamptz,
  last_message_preview   text,
  last_message_sender_id uuid,
  status                 text,
  created_at             timestamptz,
  my_unread_count        int,
  other_display_name     text,
  other_avatar_url       text,
  job_title              text
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                      AS my_unread_count,
         other.display_name                                      AS other_display_name,
         other.avatar_url                                        AS other_avatar_url,
         j.title                                                 AS job_title
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY c.last_message_at DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;
