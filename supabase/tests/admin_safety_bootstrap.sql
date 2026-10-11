-- Isolated Supabase Postgres image only. No network, Auth service or Storage
-- service is started by the runner. schema.sql excludes managed auth/storage.
-- The pinned image's supautils session hook segfaults on a denied function
-- EXECUTE, even in a fresh session. Disable that managed-role convenience hook
-- in this disposable test server; native PostgreSQL grants/RLS remain enabled.
ALTER SYSTEM SET session_preload_libraries = 'plpgsql';
SELECT pg_reload_conf();
CREATE OR REPLACE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
  SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb
$$;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone text;
ALTER TABLE auth.users ADD COLUMN IF NOT EXISTS phone_confirmed_at timestamptz;
CREATE TABLE storage.objects (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), bucket_id text, name text
);
ALTER TABLE storage.objects OWNER TO postgres;
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO authenticated;
GRANT SELECT ON storage.objects TO authenticated;
