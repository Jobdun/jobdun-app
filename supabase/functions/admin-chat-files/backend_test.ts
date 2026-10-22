import type { SupabaseClient } from "npm:@supabase/supabase-js@2.108.2";
import { createBackend } from "./backend.ts";
import { createHandler } from "./handler.ts";
const actor = "a0000000-0000-4000-8000-000000000001";
const id = "a0000000-0000-4000-8000-000000000002";
const metadata = { id, name: "notes.txt", mime: "text/plain", size: 5 };
function assert(value: unknown) {
  if (!value) throw Error("assertion failed");
}
Deno.test("expired unused upload returns410 while finalized immutable retry succeeds without rewriting bytes", async () => {
  let expired = true;
  let storageWrites = 0;
  const client = {
    auth: {
      getUser: () =>
        Promise.resolve({ data: { user: { id: actor } }, error: null }),
    },
    rpc: (name: string) => {
      if (name === "admin_chat_file_reserve") {
        return Promise.resolve(
          expired ? { data: null, error: { message: "attachment_expired" } } : {
            data: { ...metadata, path: id, state: "finalized" },
            error: null,
          },
        );
      }
      if (name === "admin_chat_file_validate") {
        return Promise.resolve({ data: metadata, error: null });
      }
      return Promise.resolve({
        data: name === "admin_chat_file_cleanup_claim" ? [] : null,
        error: null,
      });
    },
    storage: {
      from: () => {
        storageWrites++;
        throw Error("finalized retry must not write storage");
      },
    },
  } as unknown as SupabaseClient;
  const token = `e30.${
    btoa(JSON.stringify({ sub: actor, role: "authenticated", aal: "aal2" }))
  }.verified-by-test-auth`;
  const request = () => {
    const body = new FormData();
    body.set("threadId", id);
    body.set("clientTag", id);
    body.set("file", new File(["hello"], "notes.txt", { type: "text/plain" }));
    return new Request("http://localhost/files", {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
      body,
    });
  };
  const handler = createHandler(createBackend(client));
  const gone = await handler(request());
  assert(gone.status === 410);
  assert((await gone.json()).error === "attachment_expired");
  expired = false;
  const retry = await handler(request());
  assert(retry.status === 200);
  assert(
    JSON.stringify(await retry.json()) === JSON.stringify({ data: metadata }),
  );
  assert(storageWrites === 0);
});
