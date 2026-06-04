-- 20260604000004_get_inbox_company_name.sql
--
-- In the inbox/thread, show the builder counterparty by COMPANY NAME (a builder
-- is a business) and the trade counterparty by their personal display_name.
-- Builds on 20260604000003 (SECURITY DEFINER). When the counterparty is the
-- builder (c.builder_id <> p_user → the viewer is the trade) use
-- builder_profiles.company_name, falling back to display_name when blank.
--
-- Idempotent: CREATE OR REPLACE. Reversible: re-run 20260604000003.

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
         CASE
           WHEN c.builder_id <> p_user   -- counterparty is the builder (a business)
             THEN COALESCE(NULLIF(btrim(bp.company_name), ''), other.display_name)
           ELSE other.display_name        -- counterparty is the trade (a person)
         END                                                     AS other_display_name,
         other.avatar_url                                        AS other_avatar_url,
         j.title                                                 AS job_title
    FROM public.conversations c
    LEFT JOIN public.jobs j ON j.id = c.job_id
    LEFT JOIN public.profiles other
      ON other.id = CASE WHEN c.builder_id = p_user THEN c.trade_id ELSE c.builder_id END
    LEFT JOIN public.builder_profiles bp ON bp.id = c.builder_id
   WHERE auth.uid() = p_user
     AND ( (c.builder_id = p_user AND c.builder_archived_at IS NULL)
        OR (c.trade_id   = p_user AND c.trade_archived_at   IS NULL) )
   ORDER BY c.last_message_at DESC NULLS LAST;
$$;

GRANT EXECUTE ON FUNCTION public.get_inbox(uuid) TO authenticated;
