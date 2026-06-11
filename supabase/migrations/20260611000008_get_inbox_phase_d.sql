-- Phase D CP-1 §Migration 4 — get_inbox: pin/mute columns + pin-first sort
-- 20260608000005_get_inbox_phase_d.sql
-- Extends get_inbox: adds pin/mute columns + pin-first sort order.
-- Builds on 20260604000004 (SECURITY DEFINER, company_name logic).
-- Reversible: re-run 20260604000004 definition.

-- Return type gains columns -> must drop the old signature first
-- (CREATE OR REPLACE cannot change a function's return type).
DROP FUNCTION IF EXISTS public.get_inbox(uuid);

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
  job_title              text,
  -- Phase D additions
  is_pinned              boolean,
  is_muted               boolean
) LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT c.id, c.job_id, c.builder_id, c.trade_id,
         c.last_message_at, c.last_message_preview, c.last_message_sender_id,
         c.status::text, c.created_at,
         CASE WHEN c.builder_id = p_user THEN c.builder_unread_count
              ELSE c.trade_unread_count END                        AS my_unread_count,
         CASE
           WHEN c.builder_id <> p_user
             THEN COALESCE(NULLIF(btrim(bp.company_name), ''), other.display_name)
           ELSE other.display_name
         END                                                       AS other_display_name,
         other.avatar_url                                          AS other_avatar_url,
         j.title                                                   AS job_title,
         CASE WHEN c.builder_id = p_user THEN c.builder_pinned_at IS NOT NULL
              ELSE c.trade_pinned_at IS NOT NULL END               AS is_pinned,
         CASE WHEN c.builder_id = p_user THEN c.builder_muted_at IS NOT NULL
              ELSE c.trade_muted_at IS NOT NULL END                AS is_muted
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
    LEFT JOIN public.builder_profiles bp ON bp.id = c.builder_id
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY
     -- Pinned conversations float to the top per viewer
     CASE WHEN c.builder_id = p_user THEN (c.builder_pinned_at IS NOT NULL)::int
          ELSE (c.trade_pinned_at IS NOT NULL)::int
     END DESC,
     c.last_message_at DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;
