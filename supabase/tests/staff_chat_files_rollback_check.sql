-- Retained pending files must remain service-only even after schema rollback.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_policies WHERE schemaname='storage' AND tablename='objects' AND policyname='admin_chat_files_service_only' AND permissive='RESTRICTIVE') THEN RAISE EXCEPTION 'rollback retained files lost restrictive privacy policy'; END IF;
END $$;
