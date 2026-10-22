import { FileError, MAX_FILE_BYTES, validateFile } from "./validation.ts";
export type Actor = { id: string; aal: string };
export type Attachment = {
  id: string;
  name: string;
  mime: string;
  size: number;
};
export type StoredAttachment = Attachment & { path: string; state?: string };
export interface Backend {
  verify(token: string): Promise<Actor | null>;
  cleanup(): Promise<void>;
  assert(actor: Actor, thread: string): Promise<void>;
  reserve(
    actor: Actor,
    thread: string,
    tag: string,
    file: Omit<Attachment, "id">,
    hash: string,
  ): Promise<StoredAttachment>;
  put(file: StoredAttachment, bytes: Uint8Array, hash: string): Promise<void>;
  validate(actor: Actor, id: string): Promise<Attachment>;
  access(actor: Actor, id: string): Promise<StoredAttachment>;
  download(path: string): Promise<Uint8Array>;
}
const uuid = (v: unknown): v is string =>
  typeof v === "string" &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
const headers = {
  "Cache-Control": "private, no-store",
  "X-Content-Type-Options": "nosniff",
  "Vary": "Authorization",
};
const json = (data: unknown, status = 200) =>
  new Response(JSON.stringify(data), {
    status,
    headers: { ...headers, "Content-Type": "application/json" },
  });
export async function sha256(bytes: Uint8Array): Promise<string> {
  const buffer = new Uint8Array(bytes).buffer;
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", buffer)),
    (b) => b.toString(16).padStart(2, "0"),
  ).join("");
}
async function boundedBody(request: Request): Promise<Uint8Array> {
  const limit = MAX_FILE_BYTES + 65536;
  const length = request.headers.get("content-length");
  if (length && (!/^\d+$/.test(length) || Number(length) > limit)) {
    throw new FileError("invalid_file_size", 413);
  }
  if (!request.body) throw new FileError("invalid_request");
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let total = 0;
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      total += value.length;
      if (total > limit) {
        await reader.cancel();
        throw new FileError("invalid_file_size", 413);
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const body = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    body.set(chunk, offset);
    offset += chunk.length;
  }
  return body;
}
export function createHandler(backend: Backend) {
  return async (request: Request): Promise<Response> => {
    try {
      if (!["POST", "GET"].includes(request.method)) {
        return json({ error: "method_not_allowed" }, 405);
      }
      const bearer = request.headers.get("authorization")?.match(
        /^Bearer ([^\s]+)$/i,
      )?.[1];
      if (!bearer) return json({ error: "not_authenticated" }, 401);
      const actor = await backend.verify(bearer);
      if (!actor) return json({ error: "not_authenticated" }, 401);
      if (request.method === "GET") {
        const url = new URL(request.url);
        const id = url.searchParams.get("id");
        if (
          !uuid(id) || Array.from(url.searchParams.keys()).some((k) =>
            !["id", "inline"].includes(k)
          ) || url.searchParams.getAll("id").length !== 1 ||
          url.searchParams.getAll("inline").length > 1 ||
          (url.searchParams.has("inline") &&
            url.searchParams.get("inline") !== "1")
        ) {
          throw new FileError("invalid_request");
        }
        const file = await backend.access(actor, id);
        const bytes = await backend.download(file.path);
        if (bytes.length !== file.size) {
          throw new FileError("unavailable", 503);
        }
        const inline = url.searchParams.get("inline") === "1" &&
          ["image/jpeg", "image/png", "image/webp"].includes(file.mime);
        const fallback = file.name.replace(/[^a-zA-Z0-9._ -]/g, "_").replaceAll(
          '"',
          "_",
        );
        const encoded = encodeURIComponent(file.name).replace(
          /['()*]/g,
          (c) =>
            "%" + c.charCodeAt(0).toString(16).toUpperCase(),
        );
        return new Response(new Uint8Array(bytes), {
          headers: {
            ...headers,
            "Content-Type": file.mime,
            "Content-Length": String(bytes.length),
            "Content-Disposition": `${
              inline ? "inline" : "attachment"
            }; filename="${fallback}"; filename*=UTF-8''${encoded}`,
            "Content-Security-Policy": "default-src 'none'; sandbox",
            "Cross-Origin-Resource-Policy": "same-origin",
          },
        });
      }
      const contentType = request.headers.get("content-type") ?? "";
      if (!/^multipart\/form-data;\s*boundary=/i.test(contentType)) {
        throw new FileError("invalid_request");
      }
      const bytes = await boundedBody(request);
      let form: FormData;
      try {
        form = await new Request(request.url, {
          method: "POST",
          headers: { "Content-Type": contentType },
          body: new Uint8Array(bytes),
        }).formData();
      } catch {
        throw new FileError("invalid_request");
      }
      if (
        Array.from(form.keys()).some((k) =>
          !["threadId", "clientTag", "file"].includes(k)
        ) || ["threadId", "clientTag", "file"].some((k) =>
          form.getAll(k).length !== 1
        )
      ) throw new FileError("invalid_request");
      const thread = form.get("threadId"),
        tag = form.get("clientTag"),
        file = form.get("file");
      if (!uuid(thread) || !uuid(tag) || !(file instanceof File)) {
        throw new FileError("invalid_request");
      }
      const contents = new Uint8Array(await file.arrayBuffer());
      const metadata = validateFile(file.name, file.type, contents);
      const hash = await sha256(contents);
      // Opportunistic bounded cleanup. Fail closed if unavailable rather than
      // allow new reservations to grow without the cleanup mechanism.
      await backend.assert(actor, thread);
      await backend.cleanup();
      const reserved = await backend.reserve(
        actor,
        thread,
        tag,
        metadata,
        hash,
      );
      if (reserved.state === "reserved") {
        await backend.put(reserved, contents, hash);
      }
      const attachment = await backend.validate(actor, reserved.id);
      return json({ data: attachment });
    } catch (error) {
      if (error instanceof FileError) {
        return json({ error: error.message }, error.status);
      }
      return json({ error: "unavailable" }, 503);
    }
  };
}
