import { deepStrictEqual, equal, rejects } from "node:assert/strict";
import { createClient } from "npm:@supabase/supabase-js@2.108.2";
import { createBackend } from "./backend.ts";
import { createHandler } from "./handler.ts";

const actor = "00000000-0000-4000-8000-000000000001";
const token = `header.${
  btoa(JSON.stringify({ sub: actor, aal: "aal2" }))
}.signature`;
function fixture(responses: { body: unknown; status?: number }[]) {
  const calls: { url: URL; init?: RequestInit }[] = [];
  const client = createClient(
    "https://project.supabase.co",
    "test-service-key",
    {
      auth: { persistSession: false, autoRefreshToken: false },
      global: {
        fetch: (input, init) => {
          calls.push({ url: new URL(String(input)), init });
          const next = responses.shift();
          if (!next) throw new Error("Unexpected request");
          return Promise.resolve(
            new Response(JSON.stringify(next.body), {
              status: next.status ?? 200,
              headers: { "content-type": "application/json" },
            }),
          );
        },
      },
    },
  );
  return { calls, backend: createBackend(client) };
}

Deno.test("SDK adapter verifies explicit bearer with Auth, keeps service credentials separate for fresh DB check", async () => {
  const { backend, calls } = fixture([{ body: { id: actor } }, { body: true }]);
  equal(await backend.verifyUser(token), actor);
  await backend.assertAdmin(actor, token);
  equal(calls[0].url.pathname, "/auth/v1/user");
  equal(
    new Headers(calls[0].init?.headers).get("authorization"),
    `Bearer ${token}`,
  );
  equal(calls[1].url.pathname, "/rest/v1/rpc/admin_company_assert_owner");
  equal(
    new Headers(calls[1].init?.headers).get("authorization"),
    "Bearer test-service-key",
  );
  deepStrictEqual(JSON.parse(String(calls[1].init?.body)), {
    p_actor_id: actor,
    p_aal: "aal2",
  });
});

Deno.test("SDK adapter rejects failed Auth verification and denied database authorization", async () => {
  const { backend } = fixture([{
    status: 401,
    body: { message: "Invalid token", code: "bad_jwt" },
  }, { status: 403, body: { code: "42501", message: "not_authorized" } }]);
  equal(await backend.verifyUser("stale"), null);
  await rejects(() => backend.assertAdmin(actor, token), {
    message: "not_authorized",
    status: 403,
  });
});

Deno.test("old and current database authorization codes retain the Edge 403 contract", async () => {
  for (const code of ["not_authorized", "not_admin", "permission_denied"]) {
    const denied = { status: 403, body: { code: "42501", message: code } };
    const { backend } = fixture([denied, denied, denied, denied]);
    const expected = {
      message: "not_authorized",
      code: "not_authorized",
      status: 403,
    };
    await rejects(() => backend.assertAdmin(actor, token), expected);
    await rejects(
      () => backend.consume(actor, "192.0.2.1", "set-role"),
      expected,
    );
    await rejects(
      () => backend.preflightInvite(actor, "new@example.test"),
      expected,
    );
    await rejects(
      () => backend.setRole(actor, actor, "trade", "admin", "Reason"),
      expected,
    );

    const http = fixture([{ body: { id: actor } }, denied]);
    const response = await createHandler(http.backend, null)(
      new Request("https://edge.test/admin-users", {
        headers: { Authorization: `Bearer ${token}` },
      }),
    );
    equal(response.status, 403);
    deepStrictEqual(await response.json(), { error: "not_authorized" });
    equal(http.calls.length, 2);
  }
});

Deno.test("old and current last-admin codes retain the Edge 409 contract", async () => {
  const target = "00000000-0000-4000-8000-000000000002";
  for (const code of ["last_admin", "last_active_admin", "last_active_owner"]) {
    const { backend, calls } = fixture([
      { body: { id: actor } },
      { body: true },
      { body: { allowed: true, retry_after: 3600 } },
      { status: 400, body: { code: "P0001", message: code } },
    ]);
    const response = await createHandler(backend, null)(
      new Request("https://edge.test/admin-users", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          action: "set-role",
          userId: target,
          role: "builder",
          expectedRole: "admin",
          reason: "Synthetic test reason",
        }),
      }),
    );
    equal(response.status, 409);
    deepStrictEqual(await response.json(), { error: "last_admin" });
    equal(calls.length, 4);
  }
});

Deno.test("SDK invite uses built-in invite endpoint and full_name only; redirect is server supplied", async () => {
  const { backend, calls } = fixture([{ body: { id: actor } }]);
  equal(
    await backend.invite(
      "new@example.test",
      "New User",
      "https://admin.jobdun.com.au/auth/invite",
    ),
    actor,
  );
  equal(calls[0].url.pathname, "/auth/v1/invite");
  equal(
    calls[0].url.searchParams.get("redirect_to"),
    "https://admin.jobdun.com.au/auth/invite",
  );
  deepStrictEqual(JSON.parse(String(calls[0].init?.body)), {
    email: "new@example.test",
    data: { full_name: "New User" },
  });
});

Deno.test("SDK role and rate RPC contracts are exact; unknown database errors do not escape", async () => {
  const { backend, calls } = fixture([
    { body: { allowed: true, retry_after: 3600 } },
    { body: null },
    { body: { userId: actor, role: "admin" } },
    {
      status: 400,
      body: { code: "XX000", message: "private email@example.test" },
    },
  ]);
  deepStrictEqual(await backend.consume(actor, "192.0.2.1", "invite"), {
    allowed: true,
    retryAfter: 3600,
  });
  await backend.preflightInvite(actor, "new@example.test");
  deepStrictEqual(
    await backend.setRole(actor, actor, "admin", null, "Reason"),
    { userId: actor, role: "admin" },
  );
  deepStrictEqual(JSON.parse(String(calls[2].init?.body)), {
    p_actor_id: actor,
    p_user_id: actor,
    p_role: "admin",
    p_expected_role: null,
    p_reason: "Reason",
  });
  await rejects(() => backend.assertAdmin(actor, token), {
    message: "unavailable",
    status: 503,
  });
});

Deno.test("SDK adapter fails closed on malformed readiness/rate replies", async () => {
  const { backend } = fixture([{ body: null }, { body: { allowed: "yes" } }]);
  await rejects(() => backend.assertAdmin(actor, token), {
    message: "unavailable",
  });
  await rejects(() => backend.consume(actor, "unknown", "invite"), {
    message: "unavailable",
  });
});

Deno.test("owner guard rejects mismatched subjects before service RPC", async () => {
  const { backend, calls } = fixture([]);
  const wrong = `header.${
    btoa(
      JSON.stringify({
        sub: "00000000-0000-4000-8000-000000000099",
        aal: "aal2",
      }),
    )
  }.signature`;
  await rejects(() => backend.assertAdmin(actor, wrong), {
    message: "not_authorized",
  });
  equal(calls.length, 0);
});
