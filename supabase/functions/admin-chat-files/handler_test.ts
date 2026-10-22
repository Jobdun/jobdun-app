// deno-lint-ignore-file require-await
import { FileError } from "./validation.ts";
// Async dependency fakes deliberately implement the production async contract.
import { type Backend, createHandler } from "./handler.ts";
function assert(x: unknown) {
  if (!x) throw Error("assertion failed");
}
const actor = { id: "a0000000-0000-4000-8000-000000000001", aal: "aal2" };
const id = "a0000000-0000-4000-8000-000000000002";
const metadata = { id, name: "notes.txt", mime: "text/plain", size: 5 };
function backend(): Backend {
  return {
    verify: async () => actor,
    assert: () => Promise.resolve(),
    cleanup: async () => {},
    reserve: async () => ({ ...metadata, path: id, state: "reserved" }),
    put: async () => {},
    validate: async () => metadata,
    access: async () => ({ ...metadata, path: id }),
    download: async () => new Uint8Array([104, 101, 108, 108, 111]),
  };
}
function post(file = new File(["hello"], "notes.txt", { type: "text/plain" })) {
  const form = new FormData();
  form.set("threadId", id);
  form.set("clientTag", id);
  form.set("file", file);
  return new Request("http://localhost/files", {
    method: "POST",
    headers: { Authorization: "Bearer token" },
    body: form,
  });
}
Deno.test("POST validates actual bytes before reserve/write and returns only attachment metadata", async () => {
  const b = backend();
  let writes = 0;
  b.put = async () => {
    writes++;
  };
  const handle = createHandler(b);
  const response = await handle(post());
  assert(response.status === 200);
  assert(writes === 1);
  assert(
    JSON.stringify(await response.json()) ===
      JSON.stringify({ data: metadata }),
  );
  const bad = await handle(
    post(new File(["<html>oops</html>"], "notes.txt", { type: "text/plain" })),
  );
  assert(bad.status === 400);
  assert(writes === 1);
});
Deno.test("auth denial precedes body parsing, and backend errors stay private", async () => {
  const b = backend();
  b.verify = async () => null;
  const r = await createHandler(b)(
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer invalid" },
      body: "bad",
    }),
  );
  assert(r.status === 401);
  b.verify = async () => actor;
  b.reserve = async () => {
    throw Error("secret object path");
  };
  const bad = await createHandler(b)(post());
  assert(bad.status === 503);
  assert(!(await bad.text()).includes("secret"));
});
Deno.test("GET rechecks access and forces text/PDF download with private safe headers", async () => {
  const b = backend();
  const response = await createHandler(b)(
    new Request(`http://localhost/?id=${id}&inline=1`, {
      headers: { Authorization: "Bearer token" },
    }),
  );
  assert(response.status === 200);
  assert(
    response.headers.get("content-disposition")?.startsWith("attachment;"),
  );
  assert(response.headers.get("cache-control") === "private, no-store");
  assert(response.headers.get("x-content-type-options") === "nosniff");
  assert(await response.text() === "hello");
});
Deno.test("duplicate/missing fields and oversized request are rejected before persistence", async () => {
  const b = backend();
  let reservations = 0;
  b.reserve = async () => {
    reservations++;
    throw Error();
  };
  const f = new FormData();
  f.append("threadId", id);
  f.append("threadId", id);
  f.set("clientTag", id);
  f.set("file", new File(["hello"], "x.txt", { type: "text/plain" }));
  const r = await createHandler(b)(
    new Request("http://localhost", {
      method: "POST",
      headers: { Authorization: "Bearer token" },
      body: f,
    }),
  );
  assert(r.status === 400);
  assert(reservations === 0);
  const large = await createHandler(b)(
    new Request("http://localhost", {
      method: "POST",
      headers: {
        Authorization: "Bearer token",
        "content-type": "multipart/form-data; boundary=x",
      },
      body: new Uint8Array(3145728 + 65537),
    }),
  );
  assert(large.status === 413);
  assert(reservations === 0);
});
Deno.test("current staff/thread denial precedes privileged cleanup and upload", async () => {
  const b = backend();
  let cleanup = false;
  b.assert = () => Promise.reject(new FileError("chat_denied", 403));
  b.cleanup = () => {
    cleanup = true;
    return Promise.resolve();
  };
  const response = await createHandler(b)(post());
  assert(response.status === 403);
  assert(!cleanup);
});
