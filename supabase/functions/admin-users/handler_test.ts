import { deepStrictEqual, equal } from "node:assert/strict";
import {
  type Backend,
  createHandler,
  DirectoryError,
  inviteRedirect,
} from "./handler.ts";

const actor = "00000000-0000-4000-8000-000000000001";
const target = "00000000-0000-4000-8000-000000000002";
const redirect = "https://admin.jobdun.com.au/auth/invite";
const invite = {
  action: "invite",
  email: "new@example.test",
  displayName: "New User",
  role: "admin",
};
const change = {
  action: "set-role",
  userId: target,
  role: "builder",
  expectedRole: "trade",
  reason: "Requested change",
};

function setup(
  overrides: Partial<Backend> = {},
  configured: string | null = redirect,
) {
  const calls: unknown[][] = [];
  const backend: Backend = {
    verifyUser: (token) => {
      calls.push(["verify", token]);
      return Promise.resolve(actor);
    },
    assertAdmin: (id) => {
      calls.push(["admin", id]);
      return Promise.resolve();
    },
    consume: (...args) => {
      calls.push(["limit", ...args]);
      return Promise.resolve({ allowed: true, retryAfter: 3600 });
    },
    preflightInvite: (...args) => {
      calls.push(["preflight", ...args]);
      return Promise.resolve();
    },
    invite: (...args) => {
      calls.push(["invite", ...args]);
      return Promise.resolve(target);
    },
    setRole: (...args) => {
      calls.push(["role", ...args]);
      return Promise.resolve({ userId: target, role: args[2] });
    },
    ...overrides,
  };
  const handle = createHandler(backend, configured);
  const request = (body?: unknown, method = "POST", token = "valid-token") =>
    handle(
      new Request("https://edge.test/admin-users", {
        method,
        headers: {
          Authorization: `Bearer ${token}`,
          "content-type": "application/json",
          "cf-connecting-ip": "192.0.2.1",
        },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }),
      }),
    );
  return { calls, request, handle };
}

Deno.test("GET verifies token and fresh admin before reporting readiness", async () => {
  const { request, calls } = setup();
  const response = await request(undefined, "GET");
  equal(response.status, 200);
  deepStrictEqual(await response.json(), {
    ready: true,
    invitationConfigured: true,
  });
  deepStrictEqual(calls, [["verify", "valid-token"], ["admin", actor]]);
  equal(response.headers.get("cache-control"), "no-store");
  deepStrictEqual(
    await (await setup({}, null).request(undefined, "GET")).json(),
    { ready: true, invitationConfigured: false },
  );
});

Deno.test("missing, invalid and unverified bearer never reach privileged operations", async () => {
  const { handle, calls } = setup();
  equal((await handle(new Request("https://edge.test"))).status, 401);
  deepStrictEqual(calls, []);
  const invalid = setup({ verifyUser: () => Promise.resolve(null) });
  equal((await invalid.request(invite)).status, 401);
  deepStrictEqual(invalid.calls, []);
});

Deno.test("demoted or inactive actor is denied for GET and POST", async () => {
  for (const method of ["GET", "POST"]) {
    const { request, calls } = setup({
      assertAdmin: () =>
        Promise.reject(new DirectoryError("not_authorized", 403)),
    });
    equal(
      (await request(method === "POST" ? invite : undefined, method)).status,
      403,
    );
    equal(calls.length, 1);
  }
});

Deno.test("invite validates, rate limits, checks existing account, sends server redirect then applies role", async () => {
  const { request, calls } = setup();
  const response = await request({
    ...invite,
    email: "  NEW@example.test ",
    displayName: " New User ",
  });
  equal(response.status, 200);
  deepStrictEqual(await response.json(), {
    userId: target,
    invited: true,
    roleApplied: true,
  });
  deepStrictEqual(calls, [
    ["verify", "valid-token"],
    ["admin", actor],
    ["limit", actor, "192.0.2.1", "invite"],
    ["preflight", actor, "new@example.test"],
    ["invite", "new@example.test", "New User", redirect],
    ["role", actor, target, "admin", null, "Admin email invitation"],
  ]);
});

Deno.test("partial outcome explicitly reports email sent when role assignment throws", async () => {
  for (
    const error of [
      new Error("private email@example.test"),
      new DirectoryError("role_conflict", 409),
    ]
  ) {
    const { request, calls } = setup({ setRole: () => Promise.reject(error) });
    const response = await request(invite);
    equal(response.status, 200);
    deepStrictEqual(await response.json(), {
      userId: target,
      invited: true,
      roleApplied: false,
      error: "role_assignment_failed",
    });
    equal(calls.filter((c) => c[0] === "invite").length, 1);
  }
});

Deno.test("invalid input and client redirects cannot send invitations", async () => {
  for (
    const body of [
      null,
      [],
      { ...invite, role: "apprentice" },
      { ...invite, displayName: " " },
      { ...invite, email: "bad" },
      { ...invite, email: "a\nb@example.test" },
      { ...invite, redirectTo: "https://evil.test" },
      { ...invite, displayName: "a".repeat(121) },
      { ...change, expectedRole: undefined },
      { ...change, reason: " " },
      { ...change, userId: "bad" },
      { ...change, role: "owner" },
      { ...invite, actorId: target },
    ]
  ) {
    const { request, calls } = setup();
    equal((await request(body)).status, 400, JSON.stringify(body));
    equal(
      calls.filter((c) => ["invite", "role", "limit"].includes(String(c[0])))
        .length,
      0,
    );
  }
});

Deno.test("missing invitation config prevents sending but role editing remains available", async () => {
  const { request, calls } = setup({}, null);
  equal((await request(invite)).status, 503);
  equal(calls.filter((c) => c[0] === "invite").length, 0);
  equal((await request(change)).status, 200);
});

Deno.test("name 2..100, reason 5..500 and scalar roles match the UI contract", async () => {
  for (
    const body of [
      { ...invite, displayName: "A" },
      { ...invite, displayName: "A".repeat(101) },
      { ...change, reason: "four" },
      { ...change, reason: "x".repeat(501) },
      { ...invite, role: ["admin"] },
    ]
  ) {
    equal((await setup().request(body)).status, 400);
  }
  for (const displayName of ["AB", "A".repeat(100)]) {
    equal((await setup().request({ ...invite, displayName })).status, 200);
  }
  for (const reason of ["Valid", "x".repeat(500)]) {
    equal((await setup().request({ ...change, reason })).status, 200);
  }
});

Deno.test("rate denial and rate backend failure fail closed without email", async () => {
  const { request, calls } = setup({
    consume: () => Promise.resolve({ allowed: false, retryAfter: 3600 }),
  });
  const response = await request(invite);
  equal(response.status, 429);
  equal(response.headers.get("retry-after"), "3600");
  equal(calls.filter((c) => c[0] === "invite").length, 0);
  const broken = setup({
    consume: () => Promise.reject(new Error("secret database detail")),
  });
  const failure = await broken.request(invite);
  equal(failure.status, 503);
  deepStrictEqual(await failure.json(), { error: "unavailable" });
});

Deno.test("existing email returns conflict before the Auth mail API", async () => {
  const { request, calls } = setup({
    preflightInvite: () =>
      Promise.reject(new DirectoryError("user_exists", 409)),
  });
  equal((await request(invite)).status, 409);
  equal(calls.filter((c) => c[0] === "invite").length, 0);
});

Deno.test("set-role forwards expectedRole including null and verified actor; conflicts are explicit", async () => {
  for (const expectedRole of ["trade", null]) {
    const { request, calls } = setup();
    const response = await request({ ...change, expectedRole });
    deepStrictEqual(await response.json(), { userId: target, role: "builder" });
    deepStrictEqual(calls.at(-1), [
      "role",
      actor,
      target,
      "builder",
      expectedRole,
      "Requested change",
    ]);
  }
  const { request } = setup({
    setRole: () => Promise.reject(new DirectoryError("role_conflict", 409)),
  });
  const response = await request(change);
  equal(response.status, 409);
  deepStrictEqual(await response.json(), { error: "role_conflict" });
});

Deno.test("self role changes, invalid JSON, oversized bodies and unsupported methods are rejected", async () => {
  const { request, handle, calls } = setup();
  equal((await request({ ...change, userId: actor })).status, 409);
  equal(
    (await handle(
      new Request("https://edge.test", {
        method: "POST",
        headers: { Authorization: "Bearer valid" },
        body: "{",
      }),
    )).status,
    400,
  );
  equal(
    (await request({ ...invite, displayName: "a".repeat(17000) })).status,
    413,
  );
  equal((await request(undefined, "DELETE")).status, 405);
  equal(
    (await handle(new Request("https://edge.test", { method: "OPTIONS" })))
      .status,
    204,
  );
  equal(calls.filter((c) => c[0] === "role").length, 0);
});

Deno.test("only approved HTTPS redirects or local-only loopback callbacks are configured", () => {
  equal(inviteRedirect(redirect, "https://project.supabase.co"), redirect);
  equal(
    inviteRedirect("http://localhost:3000/auth/invite", "http://kong:8000"),
    "http://localhost:3000/auth/invite",
  );
  equal(
    inviteRedirect(
      "http://127.0.0.1:3000/auth/invite",
      "http://127.0.0.1:54321",
    ),
    "http://127.0.0.1:3000/auth/invite",
  );
  for (
    const url of [
      undefined,
      "",
      "http://admin.jobdun.com.au/auth/invite",
      "https://evil.test",
      "https://user:pass@admin.jobdun.com.au/auth/invite",
      "https://admin.jobdun.com.au.evil.test",
      "javascript:alert(1)",
      "http://localhost:3000/auth/invite",
      `${redirect}#token`,
    ]
  ) {
    equal(inviteRedirect(url, "https://project.supabase.co"), null, url);
  }
});
