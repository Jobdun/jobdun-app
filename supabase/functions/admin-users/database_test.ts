// Executes real PostgreSQL SQL in an isolated in-memory database. No connection
// string, .env, production credentials, email provider, or running server used.
import { deepStrictEqual, equal, rejects } from "node:assert/strict";
import { PGlite } from "npm:@electric-sql/pglite@0.5.8";

const A = "00000000-0000-4000-8000-000000000001";
const B = "00000000-0000-4000-8000-000000000002";
const T = "00000000-0000-4000-8000-000000000003";
const N = "00000000-0000-4000-8000-000000000004";
const migration = new URL(
  "../../migrations/20261007000001_admin_user_management.sql",
  import.meta.url,
);

async function baseline(db: PGlite) {
  // Pull the relevant real table/function/constraint/policy definitions from
  // the checked-in schema. Only Auth's environment and unrelated app objects
  // are omitted; tests will fail if a required definition disappears.
  // Optional fixture path allows checking origin/main independently of the
  // working branch: deno test --allow-read database_test.ts -- /tmp/schema.sql
  const schema = await Deno.readTextFile(
    new URL(Deno.args[0] ?? "../../schema.sql", import.meta.url),
  );
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
    CREATE SCHEMA auth;
    CREATE TABLE auth.users(id uuid PRIMARY KEY, email text, raw_user_meta_data jsonb DEFAULT '{}');
    CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE AS $$
      SELECT coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
    CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT (auth.jwt()->>'sub')::uuid $$;
    CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$ SELECT auth.jwt()->>'role' $$;
    GRANT USAGE ON SCHEMA auth, public TO anon, authenticated, service_role;
    CREATE TYPE public.user_status AS ENUM ('active','suspended','banned');
  `);
  const tables = [
    "profiles",
    "user_roles",
    "trade_profiles",
    "builder_profiles",
    "user_role_events",
    "admin_actions",
    "verification_rate_limits",
  ];
  for (const table of tables) {
    const definition = schema.match(
      new RegExp(
        `CREATE TABLE IF NOT EXISTS "public"\\."${table}" \\([\\s\\S]*?\\n\\);`,
      ),
    )?.[0];
    if (!definition) throw new Error(`Schema table missing: ${table}`);
    await db.exec(definition);
  }
  // All primary keys first, then foreign keys (which reference those keys).
  const constraints = [
    ...schema.matchAll(
      /ALTER TABLE ONLY "public"\."([^"]+)"\s+ADD CONSTRAINT[^;]+;/g,
    ),
  ]
    .filter((m) => tables.includes(m[1]));
  for (const foreign of [false, true]) {
    for (
      const match of constraints.filter((m) =>
        m[0].includes("FOREIGN KEY") === foreign
      )
    ) await db.exec(match[0]);
  }
  for (const table of tables) {
    await db.exec(`ALTER TABLE public.${table} ENABLE ROW LEVEL SECURITY;`);
  }
  // Test-only future-column fixture: origin/main predates apprentices. This
  // checks preservation of later profile data without requiring that feature
  // or adding any column to the production admin-management migration.
  await db.exec(
    "ALTER TABLE public.trade_profiles ADD COLUMN IF NOT EXISTS is_apprentice boolean NOT NULL DEFAULT false;",
  );
  await db.exec(`
    GRANT ALL ON ALL TABLES IN SCHEMA public TO service_role;
    GRANT SELECT, INSERT, UPDATE ON public.user_roles TO authenticated;
    GRANT SELECT ON public.profiles TO authenticated;
    INSERT INTO auth.users(id,email) VALUES ('${A}','admin-a@example.test'),('${B}','admin-b@example.test'),('${T}','trade@example.test'),('${N}','new@example.test');
    INSERT INTO profiles(id,display_name) VALUES ('${A}','Admin A'),('${B}','Admin B'),('${T}','Trade');
    INSERT INTO user_roles(user_id,role) VALUES ('${A}','admin'),('${B}','admin'),('${T}','trade');
    INSERT INTO trade_profiles(id,full_name,about,is_apprentice) VALUES ('${T}','Historical name','Keep history',true);
  `);
  for (
    const name of [
      "forbid_self_admin",
      "forbid_role_mutation",
      "log_role_event",
      "handle_new_user",
    ]
  ) {
    const definition = schema.match(
      new RegExp(
        `CREATE OR REPLACE FUNCTION "public"\\."${name}"\\([\\s\\S]*?\\n\\$\\$;`,
      ),
    )?.[0];
    if (!definition) throw new Error(`Schema function missing: ${name}`);
    await db.exec(definition);
  }
  for (
    const match of schema.matchAll(
      /CREATE OR REPLACE TRIGGER[^;]+ ON "public"\."user_roles"[^;]+;/g,
    )
  ) await db.exec(match[0]);
  for (
    const match of schema.matchAll(
      /CREATE POLICY[^;]+ ON "public"\."user_roles"[^;]+;/g,
    )
  ) await db.exec(match[0]);
  await db.exec(
    "CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();",
  );
}

async function session(
  db: PGlite,
  role = "service_role",
  sub: string | null = null,
  claimedRole = "admin",
) {
  await db.exec(`SET LOCAL ROLE ${role};`);
  await db.query("SELECT set_config('request.jwt.claims', $1, true)", [
    JSON.stringify({ role, sub, user_role: claimedRole }),
  ]);
}
async function setRole(
  db: PGlite,
  actor = A,
  target = T,
  role = "builder",
  expected: string | null = "trade",
  reason = "Approved change",
) {
  return await db.query(
    "SELECT public.admin_set_user_role($1::uuid,$2::uuid,$3,$4,$5) AS result",
    [actor, target, role, expected, reason],
  );
}

Deno.test("admin user management SQL: atomic roles, audit, RLS and service-only guards", async (t) => {
  const db = new PGlite();
  try {
    await baseline(db);
    try {
      await db.exec(await Deno.readTextFile(migration));
    } catch (error) {
      if (!(error instanceof Deno.errors.NotFound)) throw error;
    } // Red run uses current schema.
    const step = async (name: string, fn: () => Promise<void>) => {
      await t.step(name, async () => {
        await db.exec("BEGIN");
        try {
          await session(db);
          await fn();
        } finally {
          await db.exec("ROLLBACK");
        }
      });
    };
    await step("fresh readiness and service-only grants", async () => {
      deepStrictEqual(
        (await db.query(
          "SELECT admin_user_management_ready($1::uuid) AS ready",
          [A],
        )).rows,
        [{ ready: true }],
      );
      const signatures = [
        "admin_user_management_ready(uuid)",
        "admin_user_invitation_preflight(uuid,text)",
        "admin_user_management_rate_limit(uuid,text,text)",
        "admin_set_user_role(uuid,uuid,text,text,text)",
      ];
      for (const role of ["anon", "authenticated"]) {
        for (const fn of signatures) {
          deepStrictEqual(
            (await db.query(
              "SELECT has_function_privilege($1,$2,'EXECUTE') AS allowed",
              [role, fn],
            )).rows,
            [{ allowed: false }],
          );
        }
      }
    });
    await step(
      "role change creates stub, preserves trade history and audits real actor/reason",
      async () => {
        deepStrictEqual((await setRole(db)).rows, [{
          result: { userId: T, role: "builder" },
        }]);
        deepStrictEqual(
          (await db.query("SELECT id FROM builder_profiles WHERE id=$1", [T]))
            .rows,
          [{ id: T }],
        );
        deepStrictEqual(
          (await db.query(
            "SELECT full_name,about,is_apprentice FROM trade_profiles WHERE id=$1",
            [T],
          )).rows,
          [{
            full_name: "Historical name",
            about: "Keep history",
            is_apprentice: true,
          }],
        );
        deepStrictEqual(
          (await db.query(
            "SELECT old_role,new_role,changed_by,reason FROM user_role_events WHERE user_id=$1",
            [T],
          )).rows,
          [{
            old_role: "trade",
            new_role: "builder",
            changed_by: A,
            reason: "Approved change",
          }],
        );
        const audit = (await db.query<{ actor_id: string; metadata: unknown }>(
          "SELECT actor_id,metadata FROM admin_actions WHERE target_id=$1",
          [T],
        )).rows;
        deepStrictEqual(audit, [{
          actor_id: A,
          metadata: {
            old_role: "trade",
            new_role: "builder",
            reason: "Approved change",
          },
        }]);
        await setRole(db, A, T, "trade", "builder");
        equal(
          (await db.query<{ n: number }>(
            "SELECT count(*)::int AS n FROM trade_profiles WHERE id=$1",
            [T],
          )).rows[0].n,
          1,
        );
      },
    );
    await step(
      "new admin assignment allowed only through service; missing profile repaired",
      async () => {
        await setRole(db, A, N, "admin", null);
        deepStrictEqual(
          (await db.query("SELECT user_status FROM profiles WHERE id=$1", [N]))
            .rows,
          [{ user_status: "active" }],
        );
        deepStrictEqual(
          (await db.query("SELECT role FROM user_roles WHERE user_id=$1", [N]))
            .rows,
          [{ role: "admin" }],
        );
      },
    );
    await step(
      "CAS refuses stale role or unknown role and changes nothing",
      async () => {
        await rejects(() => setRole(db, A, T, "admin", null), /role_conflict/);
      },
    );
    await step("self role change forbidden", async () => {
      await rejects(
        () => setRole(db, A, A, "trade", "admin"),
        /self_role_change/,
      );
    });
    await step("demoted actor denied even with stale admin JWT", async () => {
      await setRole(db, A, B, "trade", "admin");
      await rejects(
        () => setRole(db, B, A, "trade", "admin"),
        /not_authorized/,
      );
    });
    await step("inactive actor denied", async () => {
      await db.query(
        "UPDATE profiles SET user_status='suspended' WHERE id=$1",
        [A],
      );
      await rejects(() => setRole(db), /not_authorized/);
    });
    await step("invalid role and blank reason rejected in SQL", async () => {
      await rejects(() => setRole(db, A, T, "apprentice"), /invalid_request/);
    });
    await step("blank reason rejected in SQL", async () => {
      await rejects(
        () => setRole(db, A, T, "builder", "trade", " "),
        /invalid_request/,
      );
    });
    await step("target must exist in Auth", async () => {
      await rejects(
        () =>
          setRole(db, A, "00000000-0000-4000-8000-000000000099", "admin", null),
        /user_not_found/,
      );
    });
    await step("audit failure rolls the entire mutation back", async () => {
      await db.exec(
        "RESET ROLE; ALTER TABLE admin_actions ADD CONSTRAINT test_reject CHECK(false) NOT VALID; SAVEPOINT attempt;",
      );
      await session(db);
      await rejects(() => setRole(db), /test_reject/);
      await db.exec("ROLLBACK TO SAVEPOINT attempt;");
      deepStrictEqual(
        (await db.query("SELECT role FROM user_roles WHERE user_id=$1", [T]))
          .rows,
        [{ role: "trade" }],
      );
      equal(
        (await db.query<{ n: number }>(
          "SELECT count(*)::int AS n FROM builder_profiles WHERE id=$1",
          [T],
        )).rows[0].n,
        0,
      );
      equal(
        (await db.query<{ n: number }>(
          "SELECT count(*)::int AS n FROM user_role_events",
        )).rows[0].n,
        0,
      );
    });
    await step(
      "stale admin JWT does not reveal other users' roles",
      async () => {
        await session(db, "authenticated", T, "admin");
        deepStrictEqual(
          (await db.query("SELECT user_id FROM user_roles ORDER BY user_id"))
            .rows,
          [{ user_id: T }],
        );
      },
    );
    await step(
      "active admin can read directory with stale non-admin JWT",
      async () => {
        await session(db, "authenticated", A, "trade");
        equal(
          (await db.query<{ n: number }>(
            "SELECT count(*)::int AS n FROM user_roles",
          )).rows[0].n,
          3,
        );
      },
    );
    await step("inactive admin cannot read directory roles", async () => {
      await db.query("UPDATE profiles SET user_status='banned' WHERE id=$1", [
        A,
      ]);
      await session(db, "authenticated", A);
      deepStrictEqual((await db.query("SELECT user_id FROM user_roles")).rows, [
        { user_id: A },
      ]);
    });
    await step(
      "authenticated caller cannot invoke role RPC or forge actor",
      async () => {
        await session(db, "authenticated", T);
        await rejects(() => setRole(db), /permission denied/);
      },
    );
    await step(
      "public signup still creates builder/trade, never metadata admin",
      async () => {
        await db.exec("RESET ROLE");
        for (
          const [suffix, role] of [["11", "builder"], ["12", "trade"], [
            "13",
            "admin",
          ]]
        ) {
          await db.query(
            "INSERT INTO auth.users(id,raw_user_meta_data) VALUES ($1,$2)",
            [
              `00000000-0000-4000-8000-0000000000${suffix}`,
              JSON.stringify({ role, full_name: "Signup" }),
            ],
          );
        }
        deepStrictEqual(
          (await db.query(
            "SELECT user_id,role FROM user_roles WHERE user_id IN ('00000000-0000-4000-8000-000000000011','00000000-0000-4000-8000-000000000012','00000000-0000-4000-8000-000000000013') ORDER BY user_id",
          )).rows,
          [
            {
              user_id: "00000000-0000-4000-8000-000000000011",
              role: "builder",
            },
            { user_id: "00000000-0000-4000-8000-000000000012", role: "trade" },
          ],
        );
      },
    );
    await step("self admin assignment stays forbidden", async () => {
      await session(db, "authenticated", N);
      await rejects(
        () =>
          db.query("INSERT INTO user_roles(user_id,role) VALUES ($1,'admin')", [
            N,
          ]),
        /admin role cannot be self-assigned/,
      );
    });
    await step(
      "audit context is reset after RPC before later service signup",
      async () => {
        await setRole(db);
        await db.query(
          "INSERT INTO user_roles(user_id,role) VALUES ($1,'trade')",
          [N],
        );
        deepStrictEqual(
          (await db.query(
            "SELECT changed_by,reason FROM user_role_events WHERE user_id=$1",
            [N],
          )).rows,
          [{ changed_by: null, reason: "signup" }],
        );
      },
    );
    await step(
      "existing email preflight blocks invite case-insensitively",
      async () => {
        await rejects(
          () =>
            db.query("SELECT admin_user_invitation_preflight($1::uuid,$2)", [
              A,
              "TRADE@example.test",
            ]),
          /user_exists/,
        );
      },
    );
    await step("SQL reason minimum matches UI", async () => {
      await rejects(
        () => setRole(db, A, T, "builder", "trade", "four"),
        /invalid_request/,
      );
    });
    await step("new email preflight and invitation rate limits", async () => {
      await db.query("SELECT admin_user_invitation_preflight($1::uuid,$2)", [
        A,
        "unregistered@example.test",
      ]);
      for (let i = 0; i < 6; i++) {
        const row = (await db.query<{ result: { allowed: boolean } }>(
          "SELECT admin_user_management_rate_limit($1::uuid,$2,'invite') AS result",
          [A, "192.0.2.1"],
        )).rows[0];
        equal(row.result.allowed, i < 5);
      }
      equal(
        (await db.query<{ n: number }>(
          "SELECT sum(attempt_count)::int AS n FROM verification_rate_limits WHERE bucket_key=$1 AND endpoint='admin-users-invite'",
          [`user:${A}`],
        )).rows[0].n,
        5,
      );
    });
    await step("shared IP cap denies even when actor has quota", async () => {
      await db.query(
        "INSERT INTO verification_rate_limits(bucket_key,endpoint,window_start,attempt_count) VALUES ('ip:192.0.2.1','admin-users-invite',date_trunc('minute',now()),20)",
      );
      deepStrictEqual(
        (await db.query(
          "SELECT admin_user_management_rate_limit($1::uuid,'192.0.2.1','invite')->>'allowed' AS allowed",
          [A],
        )).rows,
        [{ allowed: "false" }],
      );
      equal(
        (await db.query<{ n: number }>(
          "SELECT count(*)::int AS n FROM verification_rate_limits WHERE bucket_key=$1",
          [`user:${A}`],
        )).rows[0].n,
        0,
      );
    });
    await step(
      "role changes have independent 30-per-actor quota; expired attempts do not count",
      async () => {
        await db.query(
          "INSERT INTO verification_rate_limits(bucket_key,endpoint,window_start,attempt_count) VALUES ($1,'admin-users-set-role',now()-interval '2 hours',30)",
          [`user:${A}`],
        );
        for (let i = 0; i < 31; i++) {
          deepStrictEqual(
            (await db.query(
              "SELECT admin_user_management_rate_limit($1::uuid,'192.0.2.1','set-role')->>'allowed' AS allowed",
              [A],
            )).rows,
            [{ allowed: String(i < 30) }],
          );
        }
      },
    );
    await step(
      "missing service JWT is denied even to database owner",
      async () => {
        await db.exec(
          "RESET ROLE; SELECT set_config('request.jwt.claims','{}',true)",
        );
        await rejects(() => setRole(db), /not_authorized/);
      },
    );
    await step("only remaining admin cannot demote themselves", async () => {
      await setRole(db, A, B, "builder", "admin");
      await rejects(
        () => setRole(db, A, A, "builder", "admin"),
        /self_role_change/,
      );
    });
  } finally {
    await db.close();
  }
});
