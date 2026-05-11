-- ============================================================
-- Migration 6: Row Level Security policies
-- All tables must have RLS enabled; users only see their own data
-- except jobs (open listings are public to authenticated users).
-- ============================================================

-- -------------------------------------------------------
-- profiles
-- -------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

-- Insert is handled by the handle_new_user trigger (SECURITY DEFINER).
-- This policy covers any direct inserts the app might make as a fallback.
CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_own"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- -------------------------------------------------------
-- user_roles
-- -------------------------------------------------------
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_roles_select_own"
  ON public.user_roles FOR SELECT
  USING (auth.uid() = user_id);

-- Authenticated user can set their own role during onboarding.
-- Restricted to builder/trade — prevents self-escalation to admin.
CREATE POLICY "user_roles_insert_own"
  ON public.user_roles FOR INSERT
  WITH CHECK (
    auth.uid() = user_id
    AND role IN ('builder', 'trade')
  );

CREATE POLICY "user_roles_update_own"
  ON public.user_roles FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (
    auth.uid() = user_id
    AND role IN ('builder', 'trade')
  );

-- -------------------------------------------------------
-- builder_profiles
-- -------------------------------------------------------
ALTER TABLE public.builder_profiles ENABLE ROW LEVEL SECURITY;

-- Trades can read builder profile (needed for application detail joins)
CREATE POLICY "builder_profiles_select_authenticated"
  ON public.builder_profiles FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "builder_profiles_insert_own"
  ON public.builder_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "builder_profiles_update_own"
  ON public.builder_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- -------------------------------------------------------
-- trade_profiles
-- -------------------------------------------------------
ALTER TABLE public.trade_profiles ENABLE ROW LEVEL SECURITY;

-- Builders can read trade profiles (needed for application detail joins)
CREATE POLICY "trade_profiles_select_authenticated"
  ON public.trade_profiles FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "trade_profiles_insert_own"
  ON public.trade_profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "trade_profiles_update_own"
  ON public.trade_profiles FOR UPDATE
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- -------------------------------------------------------
-- jobs
-- -------------------------------------------------------
ALTER TABLE public.jobs ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can browse open/filled jobs
CREATE POLICY "jobs_select_open"
  ON public.jobs FOR SELECT
  USING (
    auth.role() = 'authenticated'
    AND status IN ('open', 'filled')
    AND deleted_at IS NULL
  );

-- Builders can see all their own jobs (any status)
CREATE POLICY "jobs_select_own"
  ON public.jobs FOR SELECT
  USING (auth.uid() = builder_id);

CREATE POLICY "jobs_insert_own"
  ON public.jobs FOR INSERT
  WITH CHECK (auth.uid() = builder_id);

CREATE POLICY "jobs_update_own"
  ON public.jobs FOR UPDATE
  USING (auth.uid() = builder_id)
  WITH CHECK (auth.uid() = builder_id);

-- Soft-delete: builders can set deleted_at on their own rows
CREATE POLICY "jobs_delete_own"
  ON public.jobs FOR DELETE
  USING (auth.uid() = builder_id);

-- -------------------------------------------------------
-- applications
-- -------------------------------------------------------
ALTER TABLE public.applications ENABLE ROW LEVEL SECURITY;

-- Trades see their own applications; builders see applications for their jobs
CREATE POLICY "applications_select"
  ON public.applications FOR SELECT
  USING (
    auth.uid() = trade_id
    OR auth.uid() = builder_id
  );

-- Only a trade can submit an application
CREATE POLICY "applications_insert_trade"
  ON public.applications FOR INSERT
  WITH CHECK (auth.uid() = trade_id);

-- Both parties can update (trade withdraws; builder shortlists/rejects)
CREATE POLICY "applications_update"
  ON public.applications FOR UPDATE
  USING (
    auth.uid() = trade_id
    OR auth.uid() = builder_id
  );

-- -------------------------------------------------------
-- conversations
-- -------------------------------------------------------
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "conversations_select"
  ON public.conversations FOR SELECT
  USING (
    auth.uid() = builder_id
    OR auth.uid() = trade_id
  );

CREATE POLICY "conversations_insert"
  ON public.conversations FOR INSERT
  WITH CHECK (
    auth.uid() = builder_id
    OR auth.uid() = trade_id
  );

-- -------------------------------------------------------
-- messages
-- -------------------------------------------------------
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "messages_select"
  ON public.messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

CREATE POLICY "messages_insert"
  ON public.messages FOR INSERT
  WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

-- Mark messages read
CREATE POLICY "messages_update_read"
  ON public.messages FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (c.builder_id = auth.uid() OR c.trade_id = auth.uid())
    )
  );

-- -------------------------------------------------------
-- notifications
-- -------------------------------------------------------
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notifications_select_own"
  ON public.notifications FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "notifications_update_own"
  ON public.notifications FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- -------------------------------------------------------
-- verification_documents
-- -------------------------------------------------------
ALTER TABLE public.verification_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "verification_documents_select_own"
  ON public.verification_documents FOR SELECT
  USING (auth.uid() = trade_id);

CREATE POLICY "verification_documents_insert_own"
  ON public.verification_documents FOR INSERT
  WITH CHECK (auth.uid() = trade_id);

CREATE POLICY "verification_documents_update_own"
  ON public.verification_documents FOR UPDATE
  USING (auth.uid() = trade_id)
  WITH CHECK (auth.uid() = trade_id);

-- -------------------------------------------------------
-- reviews
-- -------------------------------------------------------
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Anyone authenticated can read reviews about a user
CREATE POLICY "reviews_select_authenticated"
  ON public.reviews FOR SELECT
  USING (auth.role() = 'authenticated');

-- Only the reviewer can create their review
CREATE POLICY "reviews_insert_reviewer"
  ON public.reviews FOR INSERT
  WITH CHECK (auth.uid() = reviewer_id);

-- -------------------------------------------------------
-- Storage buckets
-- -------------------------------------------------------
-- public-media: avatars and logos — publicly readable, authenticated write to own path
INSERT INTO storage.buckets (id, name, public)
  VALUES ('public-media', 'public-media', true)
  ON CONFLICT (id) DO NOTHING;

CREATE POLICY "public_media_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'public-media');

CREATE POLICY "public_media_auth_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'public-media'
    AND auth.role() = 'authenticated'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

CREATE POLICY "public_media_auth_update"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'public-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "public_media_auth_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'public-media'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- private-docs: verification documents — owner only
INSERT INTO storage.buckets (id, name, public)
  VALUES ('private-docs', 'private-docs', false)
  ON CONFLICT (id) DO NOTHING;

CREATE POLICY "private_docs_owner_select"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'private-docs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "private_docs_owner_insert"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'private-docs'
    AND auth.role() = 'authenticated'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "private_docs_owner_delete"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'private-docs'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
