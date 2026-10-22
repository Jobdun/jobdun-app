import type { SupabaseClient } from "npm:@supabase/supabase-js@2.108.2";
import { type Backend, sha256 } from "./handler.ts";
import { FileError } from "./validation.ts";
const errors: Record<string, number> = {
  chat_denied: 403,
  recipient_unavailable: 403,
  invalid_file: 400,
  invalid_attachment: 400,
  attachment_expired: 410,
  retry_payload_changed: 409,
  attachment_rate_limit: 429,
};
export function createBackend(client: SupabaseClient): Backend {
  async function rpc(name: string, args: Record<string, unknown> = {}) {
    const { data, error } = await client.rpc(name, args);
    if (error) {
      throw new FileError(
        Object.hasOwn(errors, error.message) ? error.message : "unavailable",
        errors[error.message] ?? 503,
      );
    }
    return data;
  }
  return {
    async verify(token) {
      const { data, error } = await client.auth.getUser(token);
      if (error || !data.user) return null;
      // Auth verified this exact token. Only now use its assurance claim, tied to
      // the verified subject; never accept caller-supplied actor/AAL form fields.
      try {
        const claim = JSON.parse(
          atob(token.split(".")[1].replaceAll("-", "+").replaceAll("_", "/")),
        );
        if (
          claim.sub !== data.user.id || claim.role !== "authenticated" ||
          !["aal1", "aal2"].includes(claim.aal)
        ) return null;
        return { id: data.user.id, aal: claim.aal };
      } catch {
        return null;
      }
    },
    async assert(actor, thread) {
      await rpc("admin_chat_file_require", {
        p_actor: actor.id,
        p_aal: actor.aal,
        p_thread: thread,
      });
    },
    async reserve(actor, thread, tag, file, hash) {
      return await rpc("admin_chat_file_reserve", {
        p_actor: actor.id,
        p_aal: actor.aal,
        p_thread: thread,
        p_client_tag: tag,
        p_name: file.name,
        p_mime: file.mime,
        p_size: file.size,
        p_sha256: hash,
      });
    },
    async put(file, bytes, hash) {
      const { error } = await client.storage.from("admin-chat-files").upload(
        file.path,
        bytes,
        { contentType: file.mime, upsert: false, cacheControl: "0" },
      );
      if (error) {
        // A concurrent identical request may already have stored the immutable
        // object. Never overwrite; verify actual bytes before trusting the retry.
        const existing = await client.storage.from("admin-chat-files").download(
          file.path,
        );
        if (
          existing.error || !existing.data ||
          await sha256(new Uint8Array(await existing.data.arrayBuffer())) !==
            hash
        ) throw new FileError("unavailable", 503);
      }
    },
    async validate(actor, id) {
      return await rpc("admin_chat_file_validate", {
        p_actor: actor.id,
        p_aal: actor.aal,
        p_id: id,
      });
    },
    async access(actor, id) {
      return await rpc("admin_chat_file_access", {
        p_actor: actor.id,
        p_aal: actor.aal,
        p_id: id,
      });
    },
    async download(path) {
      const { data, error } = await client.storage.from("admin-chat-files")
        .download(path);
      if (error || !data) throw new FileError("unavailable", 503);
      return new Uint8Array(await data.arrayBuffer());
    },
    async cleanup() {
      const files = await rpc("admin_chat_file_cleanup_claim");
      for (const file of files) {
        const { error } = await client.storage.from("admin-chat-files").remove([
          file.path,
        ]);
        if (!error) {
          await rpc("admin_chat_file_cleanup_done", { p_id: file.id });
        }
      }
    },
  };
}
