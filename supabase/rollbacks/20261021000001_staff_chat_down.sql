-- Roll back the web first. Export/retain private message data before destructive rollback.
BEGIN;
DROP FUNCTION public.admin_chat_read(uuid,bigint),public.admin_chat_send(uuid,text,uuid),public.admin_chat_history(uuid,bigint,bigint),public.admin_chat_inbox(),public.admin_chat_open(uuid),public.admin_chat_staff(text);
DROP TABLE public.admin_chat_reads,public.admin_chat_messages,public.admin_chat_threads;
DROP FUNCTION public.admin_chat_member(uuid),public.admin_chat_require(),public.admin_chat_allowed(),public.admin_chat_eligible(uuid);
COMMIT;
