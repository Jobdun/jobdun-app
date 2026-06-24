# Admin Web — Phase 1 (Auth + SSR gate + app shell) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Supabase SSR auth to `admin-web/` — a cookie-based session, a middleware **`user_role === 'admin'`** gate over the `(admin)` route group, a faithful `/login` page, and the collapsible sidebar + topbar app shell — then deploy with the Supabase env vars wired.

**Architecture:** `@supabase/ssr` cookie sessions. A root `middleware.ts` refreshes the session and reads the custom `user_role` claim (injected by Jobdun's `custom_access_token_hook`) via `getClaims()`, redirecting per the Flutter admin's exact matrix. Login + sign-out are **Server Actions**; the login form does instant client validation (react-hook-form + zod) and shows the server's auth error in a banner. The shell is a server `(admin)/layout.tsx` that fetches the session email and renders a client `Sidebar` (collapse state, active highlighting) + client `Topbar` (title from pathname). **Zero backend changes** — same project, anon key, claim, RPCs.

**Tech Stack:** Next.js 16 App Router, React 19.2, `@supabase/supabase-js`, `@supabase/ssr`, `react-hook-form` + `zod` + `@hookform/resolvers`, `@phosphor-icons/react`, Tailwind v4 (P0 tokens), Vitest.

**Reference:** spec `docs/superpowers/specs/2026-06-24-admin-web-nextjs-migration-design.md`; P0 plan (built) `docs/superpowers/plans/2026-06-24-admin-web-phase0-foundation.md`. Working dir: `/Users/kuya/Documents/Jobdun/admin-web` (its own git repo, remote `KpG782/jobdun-admin-web`).

---

## Ported facts (authoritative — from the Flutter admin)

**Auth:**
- Admin claim: **`user_role === 'admin'`** (string equality). Anon key only.
- Sign-in: `signInWithPassword` → if role ≠ admin, `signOut()` + error **"This account does not have admin access."**; on bad creds, error **"Invalid email or password."**
- Session = `{ userId, email }`.
- **Redirect matrix** (applied in middleware): session loading → no action; **not-admin & not at `/login` → `/login`**; **admin & at `/login` → `/`**; else no redirect.
- Routes: `/login`, `/` (dashboard), `/verifications`, `/users` (+`/users/[id]`), `/jobs` (+`/jobs/[id]`), `/audit`, `/broadcast`, `/payments`.

**Login copy/layout:** split ≥880px (brand-left on `surface` + right border / form-right on `background`), stacked card <880px. Brand: lockup + **"RUN THE PLATFORM."** + "Verifications, user moderation, and platform health in one console." + 3 capabilities (VERIFICATION QUEUE / USER MANAGEMENT / AUDIT & SECURITY) + footer "RESTRICTED ACCESS · AUTHORISED ADMINS ONLY". Form: title **"SIGN IN"**, EMAIL (hint `admin@jobdun.com.au`, errors "Email is required."/"Enter a valid email."), PASSWORD (hint `enter password`, error "Password is required."), error banner, **"LOG IN"** button (spinner when pending), helper "Unauthorised sign-ins are signed out automatically."

**Shell:** Sidebar 240/72px, 200ms, item 44px, active = `surface-raised` bg + 3px orange left bar. Nav order: DASHBOARD `/`, VERIFICATIONS `/verifications`, USERS `/users`, JOBS `/jobs`, AUDIT LOG `/audit`, BROADCAST `/broadcast`, PAYMENTS `/payments` (lock badge, navigable), BILLING (locked, non-nav). Bottom: "SIGNED IN AS" + email + **SIGN OUT**. Auto-collapse <1024px (user toggle overrides, not persisted). Topbar 64px, page title from route + optional trailing. Brand lockup = badge + "JOBDUN" + orange "ADMIN".

**Typography map (Oswald/Open Sans → P0 Archivo/Inter `.t-*`):** display→`t-display-md`; dialogTitle/sectionTitle→`t-headline-sm`/`t-title-lg`; pageTitle→`t-title-lg`; nav label/button→`t-label`; eyebrow/SIGNED-IN-AS/capability→`t-eyebrow`; body→`t-body-md`; small value→`t-body-sm`. **Colors: use P0 tokens only** (`bg-surface`, `bg-surface-raised`, `text-text1/2/3`, `bg-action`/`text-on-action`, `border-border`, `bg-urgent-bg`/`text-urgent-tx`) — NOT the Flutter raw hexes.

---

## File structure (P1 adds, under `admin-web/`)

| File | Responsibility |
|---|---|
| `lib/supabase/server.ts` | `createClient()` server client (cookies via next/headers). |
| `lib/supabase/client.ts` | `createClient()` browser client. |
| `lib/supabase/middleware.ts` | `updateSession(request)` — refresh + return `{ response, claims }`. |
| `lib/auth.ts` | `ADMIN_ROLE`, `isAdminClaims()`, `getAdminSession()`, `signOut()` action. |
| `middleware.ts` (root) | The gate: updateSession + redirect matrix + matcher. |
| `app/login/page.tsx` | Split brand/form login layout (server). |
| `app/login/login-form.tsx` | `"use client"` form (RHF+zod, banner, pending). |
| `app/login/actions.ts` | `signInAction` Server Action. |
| `lib/admin/nav.ts` | Nav item config (label/route/icons/locked/tooltip) + route→title map. |
| `components/admin/admin-brand.tsx` | JOBDUN + ADMIN lockup. |
| `components/admin/sidebar.tsx` | `"use client"` collapsible sidebar (active, session, sign-out). |
| `components/admin/topbar.tsx` | `"use client"` topbar (title from pathname). |
| `app/(admin)/layout.tsx` | Server shell: session → Sidebar + Topbar + main. |
| `app/(admin)/page.tsx` | The P0 showcase, MOVED here (now gated). |
| `.env.local`, `.env.example` | `NEXT_PUBLIC_SUPABASE_URL` / `_ANON_KEY`. |
| `public/brand/jobdun-badge.svg` | Brand badge copied from marketing-site. |

> **Orchestration:** Stage A (sequential, security core) = Tasks 1–2. Stage B (2 parallel agents) = Task 3 (login) ∥ Tasks 4–5 (shell). Stage C (integration) = Task 6.

---

## Task 1: Deps, env, Supabase clients, auth helpers

**Files:** `package.json`; `.env.local`; `.env.example`; `lib/supabase/server.ts`; `lib/supabase/client.ts`; `lib/supabase/middleware.ts`; `lib/auth.ts`; `__tests__/auth.test.ts`.

- [ ] **Step 1: Install deps**

Run: `npm install @supabase/supabase-js @supabase/ssr react-hook-form zod @hookform/resolvers`
Expected: added to `dependencies`, no peer errors.

- [ ] **Step 2: Env files**

`.env.example`:
```bash
NEXT_PUBLIC_SUPABASE_URL=https://zethpanvkfyijislxesn.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key
```
`.env.local` — copy the **real** values from the monorepo's client-safe env. Run:
```bash
grep -E 'SUPABASE_URL|SUPABASE_ANON_KEY|SUPABASE_PUBLISHABLE_KEY' /Users/kuya/Documents/Jobdun/.env
```
Map `SUPABASE_URL`→`NEXT_PUBLIC_SUPABASE_URL` and `SUPABASE_ANON_KEY` (or `SUPABASE_PUBLISHABLE_KEY`)→`NEXT_PUBLIC_SUPABASE_ANON_KEY` into `.env.local`. (`.env*` is gitignored — never commit real keys. The anon key is client-safe by design.)

- [ ] **Step 3: `lib/supabase/server.ts`**

```ts
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";

/** Per-request server client for Server Components and Server Actions. */
export async function createClient() {
  const cookieStore = await cookies();
  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => cookieStore.getAll(),
        setAll: (cookiesToSet) => {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options),
            );
          } catch {
            // Called from a Server Component (read-only cookies) — the
            // middleware refreshes the session, so this is safe to ignore.
          }
        },
      },
    },
  );
}
```

- [ ] **Step 4: `lib/supabase/client.ts`**

```ts
import { createBrowserClient } from "@supabase/ssr";

/** Browser client for the rare client-component that needs Supabase directly. */
export function createClient() {
  return createBrowserClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
  );
}
```

- [ ] **Step 5: `lib/supabase/middleware.ts`**

```ts
import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";

/**
 * Refresh the Supabase session on every request and expose the JWT claims.
 * Returns the SAME response object whose cookies were updated — the caller
 * MUST return it (or copy its cookies) or sessions desync / users log out.
 */
export async function updateSession(request: NextRequest) {
  let response = NextResponse.next({ request });

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll: () => request.cookies.getAll(),
        setAll: (cookiesToSet) => {
          cookiesToSet.forEach(({ name, value }) =>
            request.cookies.set(name, value),
          );
          response = NextResponse.next({ request });
          cookiesToSet.forEach(({ name, value, options }) =>
            response.cookies.set(name, value, options),
          );
        },
      },
    },
  );

  // Do NOT run code between createServerClient and getClaims — it refreshes
  // the token and writes cookies via setAll above.
  const { data } = await supabase.auth.getClaims();
  const claims = (data?.claims ?? null) as Record<string, unknown> | null;

  return { response, claims };
}
```

- [ ] **Step 6: Write the failing auth-helper test**

`__tests__/auth.test.ts`:
```ts
import { isAdminClaims, ADMIN_ROLE } from "@/lib/auth";

test("ADMIN_ROLE is 'admin'", () => {
  expect(ADMIN_ROLE).toBe("admin");
});

test("isAdminClaims true only when user_role === 'admin'", () => {
  expect(isAdminClaims({ user_role: "admin", sub: "u1" })).toBe(true);
  expect(isAdminClaims({ user_role: "builder" })).toBe(false);
  expect(isAdminClaims({ user_role: "trade" })).toBe(false);
  expect(isAdminClaims({})).toBe(false);
  expect(isAdminClaims(null)).toBe(false);
});
```

- [ ] **Step 7: Run it — expect FAIL** (`Cannot find module '@/lib/auth'`)

Run: `npm run test -- auth`

- [ ] **Step 8: `lib/auth.ts`**

```ts
import "server-only";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";

/** The single admin role value, matching the Flutter `user_role == 'admin'` gate. */
export const ADMIN_ROLE = "admin" as const;

export type AdminSession = { userId: string; email: string };

/** Pure claim check — the JWT `user_role` claim from custom_access_token_hook. */
export function isAdminClaims(
  claims: Record<string, unknown> | null | undefined,
): boolean {
  return !!claims && claims["user_role"] === ADMIN_ROLE;
}

/** Verified admin session for Server Components, or null. */
export async function getAdminSession(): Promise<AdminSession | null> {
  const supabase = await createClient();
  const { data } = await supabase.auth.getClaims();
  const claims = (data?.claims ?? null) as Record<string, unknown> | null;
  if (!isAdminClaims(claims)) return null;
  return {
    userId: String(claims!["sub"] ?? ""),
    email: String(claims!["email"] ?? ""),
  };
}

/** Sign-out Server Action — used by the sidebar. */
export async function signOut() {
  "use server";
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect("/login");
}
```

- [ ] **Step 9: Run the test — expect PASS.** Run: `npm run test -- auth`

- [ ] **Step 10: Commit.** `git add lib/supabase lib/auth.ts package.json package-lock.json .env.example __tests__/auth.test.ts && git commit -m "feat: supabase ssr clients + admin auth helpers"`

---

## Task 2: Root middleware (the admin gate)

**Files:** `middleware.ts`; `lib/admin/redirect.ts`; `__tests__/redirect.test.ts`.

- [ ] **Step 1: Failing test for the pure redirect decision**

`__tests__/redirect.test.ts`:
```ts
import { adminRedirect } from "@/lib/admin/redirect";

test("anon away from /login → /login", () => {
  expect(adminRedirect({ isAdmin: false, pathname: "/" })).toBe("/login");
  expect(adminRedirect({ isAdmin: false, pathname: "/users" })).toBe("/login");
});
test("anon already at /login → no redirect", () => {
  expect(adminRedirect({ isAdmin: false, pathname: "/login" })).toBeNull();
});
test("admin at /login → /", () => {
  expect(adminRedirect({ isAdmin: true, pathname: "/login" })).toBe("/");
});
test("admin on a protected route → no redirect", () => {
  expect(adminRedirect({ isAdmin: true, pathname: "/verifications" })).toBeNull();
});
```

- [ ] **Step 2: Run — expect FAIL.** Run: `npm run test -- redirect`

- [ ] **Step 3: `lib/admin/redirect.ts`**

```ts
/** Pure port of the Flutter admin redirect matrix. Returns a path or null. */
export function adminRedirect({
  isAdmin,
  pathname,
}: {
  isAdmin: boolean;
  pathname: string;
}): string | null {
  const atLogin = pathname === "/login";
  if (!isAdmin && !atLogin) return "/login";
  if (isAdmin && atLogin) return "/";
  return null;
}
```

- [ ] **Step 4: Run — expect PASS.** Run: `npm run test -- redirect`

- [ ] **Step 5: `middleware.ts` (root)**

```ts
import { NextResponse, type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/middleware";
import { isAdminClaims } from "@/lib/auth";
import { adminRedirect } from "@/lib/admin/redirect";

export async function middleware(request: NextRequest) {
  const { response, claims } = await updateSession(request);

  const target = adminRedirect({
    isAdmin: isAdminClaims(claims),
    pathname: request.nextUrl.pathname,
  });

  if (target && target !== request.nextUrl.pathname) {
    const url = request.nextUrl.clone();
    url.pathname = target;
    // Redirect, but carry over the refreshed auth cookies from `response`.
    const redirectResponse = NextResponse.redirect(url);
    response.cookies.getAll().forEach((c) =>
      redirectResponse.cookies.set(c.name, c.value),
    );
    return redirectResponse;
  }

  return response;
}

export const config = {
  // Run on everything except static assets and the favicon.
  matcher: ["/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|webp|ico)$).*)"],
};
```

> Note: `lib/auth.ts` imports `server-only`; `isAdminClaims` is a pure function so it's safe in middleware. If `server-only` trips the middleware (edge) build, move `isAdminClaims` + `ADMIN_ROLE` into `lib/admin/redirect.ts` (no `server-only`) and re-export from `lib/auth.ts`. Verify with `npm run build` in Task 6.

- [ ] **Step 6: Commit.** `git add middleware.ts lib/admin/redirect.ts __tests__/redirect.test.ts && git commit -m "feat: admin SSR gate middleware (user_role==admin redirect matrix)"`

---

## Task 3: Login — Server Action + form + page  *(Stage B, parallel agent #1)*

**Files:** `app/login/actions.ts`; `app/login/login-form.tsx`; `app/login/page.tsx`.

- [ ] **Step 1: `app/login/actions.ts`**

```ts
"use server";
import { redirect } from "next/navigation";
import { createClient } from "@/lib/supabase/server";
import { isAdminClaims } from "@/lib/auth";

export type SignInResult = { error: string } | void;

/** Sign in, enforce the admin role, set the session cookie, then redirect. */
export async function signInAction(values: {
  email: string;
  password: string;
}): Promise<SignInResult> {
  const supabase = await createClient();

  const { error } = await supabase.auth.signInWithPassword({
    email: values.email.trim(),
    password: values.password,
  });
  if (error) return { error: "Invalid email or password." };

  const { data } = await supabase.auth.getClaims();
  if (!isAdminClaims((data?.claims ?? null) as Record<string, unknown> | null)) {
    await supabase.auth.signOut();
    return { error: "This account does not have admin access." };
  }

  redirect("/");
}
```

- [ ] **Step 2: `app/login/login-form.tsx`** (client; RHF + zod; exact copy; pending; banner)

```tsx
"use client";
import { useState, useTransition } from "react";
import { useForm } from "react-hook-form";
import { zodResolver } from "@hookform/resolvers/zod";
import { z } from "zod";
import { WarningCircle, Eye, EyeSlash } from "@phosphor-icons/react";
import { Button } from "@/components/ui/button";
import { signInAction } from "./actions";

const schema = z.object({
  email: z.string().min(1, "Email is required.").email("Enter a valid email."),
  password: z.string().min(1, "Password is required."),
});
type Values = z.infer<typeof schema>;

export function LoginForm() {
  const [authError, setAuthError] = useState<string | null>(null);
  const [show, setShow] = useState(false);
  const [pending, startTransition] = useTransition();
  const {
    register,
    handleSubmit,
    formState: { errors },
  } = useForm<Values>({ resolver: zodResolver(schema) });

  const onSubmit = (values: Values) => {
    setAuthError(null);
    startTransition(async () => {
      const result = await signInAction(values);
      if (result?.error) setAuthError(result.error);
    });
  };

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate className="flex flex-col gap-4">
      <h1 className="t-headline-sm text-text1">SIGN IN</h1>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="email" className="t-eyebrow text-text2">EMAIL</label>
        <input
          id="email" type="email" autoComplete="username" placeholder="admin@jobdun.com.au"
          aria-invalid={!!errors.email}
          className="h-11 rounded-input border bg-surface px-4 t-body-md text-text1 placeholder:text-text3 transition-jobdun focus-visible:outline-none focus-visible:border-action focus-visible:ring-2 focus-visible:ring-action data-[err=true]:border-urgent"
          data-err={!!errors.email}
          {...register("email")}
        />
        {errors.email && <p role="alert" className="t-body-sm text-urgent-tx">{errors.email.message}</p>}
      </div>

      <div className="flex flex-col gap-1.5">
        <label htmlFor="password" className="t-eyebrow text-text2">PASSWORD</label>
        <div className="relative">
          <input
            id="password" type={show ? "text" : "password"} autoComplete="current-password" placeholder="enter password"
            aria-invalid={!!errors.password}
            className="h-11 w-full rounded-input border bg-surface px-4 pr-11 t-body-md text-text1 placeholder:text-text3 transition-jobdun focus-visible:outline-none focus-visible:border-action focus-visible:ring-2 focus-visible:ring-action data-[err=true]:border-urgent"
            data-err={!!errors.password}
            {...register("password")}
          />
          <button
            type="button" onClick={() => setShow((s) => !s)}
            aria-label={show ? "Hide password" : "Show password"}
            className="absolute inset-y-0 right-0 grid w-11 place-items-center text-text2 hover:text-text1 cursor-pointer"
          >
            {show ? <EyeSlash size={18} aria-hidden /> : <Eye size={18} aria-hidden />}
          </button>
        </div>
        {errors.password && <p role="alert" className="t-body-sm text-urgent-tx">{errors.password.message}</p>}
      </div>

      {authError && (
        <div role="alert" className="flex items-center gap-2 rounded-chip border border-urgent/40 bg-urgent-bg px-3 py-2.5">
          <WarningCircle size={18} weight="fill" className="shrink-0 text-urgent-tx" aria-hidden />
          <span className="t-body-sm text-urgent-tx">{authError}</span>
        </div>
      )}

      <Button type="submit" size="lg" disabled={pending} className="mt-2 w-full">
        {pending ? "SIGNING IN…" : "LOG IN"}
      </Button>
      <p className="t-body-sm text-text3">Unauthorised sign-ins are signed out automatically.</p>
    </form>
  );
}
```

- [ ] **Step 3: `app/login/page.tsx`** (split brand/form, stacks <880px via `laptop:`)

```tsx
import { SealCheck, Users, ShieldCheck } from "@phosphor-icons/react/dist/ssr";
import { AdminBrand } from "@/components/admin/admin-brand";
import { LoginForm } from "./login-form";

const CAPABILITIES = [
  { Icon: SealCheck, label: "VERIFICATION QUEUE" },
  { Icon: Users, label: "USER MANAGEMENT" },
  { Icon: ShieldCheck, label: "AUDIT & SECURITY" },
];

export default function LoginPage() {
  return (
    <main className="grid min-h-dvh laptop:grid-cols-[5fr_6fr]">
      {/* Brand panel */}
      <section className="hidden flex-col justify-between border-r border-border bg-surface p-14 laptop:flex">
        <div className="flex flex-col gap-10">
          <AdminBrand badgeSize={44} />
          <div className="flex flex-col gap-3.5">
            <h2 className="t-display-md text-text1">RUN THE PLATFORM.</h2>
            <p className="max-w-sm t-body-md text-text2">
              Verifications, user moderation, and platform health in one console.
            </p>
          </div>
          <ul className="flex flex-col gap-4">
            {CAPABILITIES.map(({ Icon, label }) => (
              <li key={label} className="flex items-center gap-3">
                <Icon size={18} weight="bold" className="text-text3" aria-hidden />
                <span className="t-eyebrow text-text2">{label}</span>
              </li>
            ))}
          </ul>
        </div>
        <p className="t-eyebrow text-text3">RESTRICTED ACCESS · AUTHORISED ADMINS ONLY</p>
      </section>

      {/* Form panel */}
      <section className="flex items-center justify-center bg-background p-6 laptop:p-12">
        <div className="w-full max-w-sm">
          <div className="mb-8 laptop:hidden"><AdminBrand badgeSize={40} /></div>
          <LoginForm />
        </div>
      </section>
    </main>
  );
}
```

- [ ] **Step 4: Commit (parallel agent: write files + `npm run test`/scoped only; the orchestrator commits at integration).** If running solo: `git add app/login && git commit -m "feat: admin login (server action + RHF form + split layout)"`

---

## Task 4: Nav config + AdminBrand  *(Stage B, parallel agent #2 — part 1)*

**Files:** `lib/admin/nav.ts`; `components/admin/admin-brand.tsx`; `public/brand/jobdun-badge.svg`.

- [ ] **Step 1: Copy the brand badge**

```bash
mkdir -p /Users/kuya/Documents/Jobdun/admin-web/public/brand
cp /Users/kuya/Documents/Jobdun/marketing-site/public/jobdun-badge.svg /Users/kuya/Documents/Jobdun/admin-web/public/brand/jobdun-badge.svg 2>/dev/null \
 || cp "$(ls /Users/kuya/Documents/Jobdun/marketing-site/public/brand/*mark*.svg 2>/dev/null | head -1)" /Users/kuya/Documents/Jobdun/admin-web/public/brand/jobdun-badge.svg
```
If neither exists, list `marketing-site/public` + `marketing-site/public/brand` and copy the badge/mark SVG to `public/brand/jobdun-badge.svg`.

- [ ] **Step 2: `lib/admin/nav.ts`**

```ts
import {
  House, SealCheck, Users, Briefcase, Shield, PaperPlaneRight, CurrencyDollar, CreditCard,
} from "@phosphor-icons/react/dist/ssr";
import type { Icon } from "@phosphor-icons/react";

export type NavItem = {
  label: string;
  href: string;
  Icon: Icon;
  locked?: boolean;       // visible, muted, non-navigable
  comingSoon?: boolean;   // navigable, lock badge
  tooltip?: string;
};

export const NAV_ITEMS: NavItem[] = [
  { label: "DASHBOARD", href: "/", Icon: House },
  { label: "VERIFICATIONS", href: "/verifications", Icon: SealCheck },
  { label: "USERS", href: "/users", Icon: Users },
  { label: "JOBS", href: "/jobs", Icon: Briefcase },
  { label: "AUDIT LOG", href: "/audit", Icon: Shield },
  { label: "BROADCAST", href: "/broadcast", Icon: PaperPlaneRight },
  { label: "PAYMENTS", href: "/payments", Icon: CurrencyDollar, comingSoon: true, tooltip: "Payments & payouts — Stage 1 · M5" },
  { label: "BILLING", href: "/", Icon: CreditCard, locked: true, tooltip: "Billing — Phase 3 · read-only tier visibility" },
];

/** Topbar title for a pathname (longest-prefix match; falls back to ADMIN). */
export function titleForPath(pathname: string): string {
  const match = NAV_ITEMS.filter((n) => !n.locked)
    .filter((n) => (n.href === "/" ? pathname === "/" : pathname.startsWith(n.href)))
    .sort((a, b) => b.href.length - a.href.length)[0];
  return match?.label ?? "ADMIN";
}
```

- [ ] **Step 3: `components/admin/admin-brand.tsx`**

```tsx
import Image from "next/image";

/** JOBDUN wordmark + orange ADMIN label, with the badge mark. */
export function AdminBrand({ badgeSize = 28, label = "ADMIN" }: { badgeSize?: number; label?: string }) {
  return (
    <div className="flex items-center gap-3">
      <Image src="/brand/jobdun-badge.svg" alt="" width={badgeSize} height={badgeSize} aria-hidden priority />
      <div className="flex flex-col leading-none">
        <span className="font-display font-extrabold uppercase tracking-[0.18em] text-text1" style={{ fontSize: badgeSize * 0.46 }}>
          JOBDUN
        </span>
        <span className="mt-0.5 t-eyebrow text-action-ink">{label}</span>
      </div>
    </div>
  );
}
```

> The inline `fontSize` here is the ONE sanctioned exception — the wordmark scales with the badge. All other type uses the `.t-*` ramp.

- [ ] **Step 4: Commit (or hand to integration).** `git add lib/admin/nav.ts components/admin/admin-brand.tsx public/brand && git commit -m "feat: admin nav config + brand lockup"`

---

## Task 5: Sidebar + Topbar + (admin) layout  *(Stage B, parallel agent #2 — part 2)*

**Files:** `components/admin/sidebar.tsx`; `components/admin/topbar.tsx`; `app/(admin)/layout.tsx`; move `app/page.tsx` → `app/(admin)/page.tsx`.

- [ ] **Step 1: `components/admin/sidebar.tsx`** (client: collapse + active + sign-out)

```tsx
"use client";
import Link from "next/link";
import { usePathname } from "next/navigation";
import { useEffect, useState } from "react";
import { Sidebar as SidebarIcon, Lock, SignOut } from "@phosphor-icons/react";
import { AdminBrand } from "@/components/admin/admin-brand";
import { NAV_ITEMS } from "@/lib/admin/nav";
import { signOut } from "@/lib/auth";
import { cn } from "@/lib/utils";

export function Sidebar({ email }: { email: string }) {
  const pathname = usePathname();
  const [userCollapsed, setUserCollapsed] = useState<boolean | null>(null);
  const [autoCollapsed, setAutoCollapsed] = useState(false);

  // Auto-collapse < 1024px unless the user has toggled (not persisted).
  useEffect(() => {
    const mq = window.matchMedia("(max-width: 1023px)");
    const apply = () => setAutoCollapsed(mq.matches);
    apply();
    mq.addEventListener("change", apply);
    return () => mq.removeEventListener("change", apply);
  }, []);
  const collapsed = userCollapsed ?? autoCollapsed;

  const isActive = (href: string) => (href === "/" ? pathname === "/" : pathname.startsWith(href));

  return (
    <aside
      className={cn(
        "flex shrink-0 flex-col border-r border-border bg-surface transition-[width] duration-200 ease-[var(--ease-jobdun)]",
        collapsed ? "w-[72px]" : "w-60",
      )}
    >
      <div className={cn("flex items-center gap-2 p-5", collapsed && "flex-col")}>
        {collapsed ? (
          <AdminBrand badgeSize={32} label="" />
        ) : (
          <Link href="/" className="min-w-0 flex-1"><AdminBrand badgeSize={26} /></Link>
        )}
        <button
          type="button" onClick={() => setUserCollapsed(!collapsed)}
          aria-label={collapsed ? "Expand sidebar" : "Collapse sidebar"}
          className="grid h-9 w-9 shrink-0 place-items-center rounded-btn text-text1 hover:bg-surface-raised cursor-pointer"
        >
          <SidebarIcon size={18} aria-hidden />
        </button>
      </div>

      <nav className="flex flex-col gap-0.5 px-3 py-2">
        {NAV_ITEMS.map((item) => {
          const active = !item.locked && isActive(item.href);
          const muted = item.locked || item.comingSoon;
          const content = (
            <>
              <span className={cn("absolute left-0 top-1/2 h-6 w-[3px] -translate-y-1/2 rounded-full bg-action", active ? "opacity-100" : "opacity-0")} aria-hidden />
              <item.Icon size={18} weight={active ? "fill" : "bold"} aria-hidden className="shrink-0" />
              {!collapsed && <span className="t-label truncate">{item.label}</span>}
              {!collapsed && (item.locked || item.comingSoon) && <Lock size={14} className="ml-auto text-text3" aria-hidden />}
            </>
          );
          const cls = cn(
            "relative flex h-11 items-center gap-3 rounded-btn px-3 transition-jobdun",
            collapsed && "justify-center",
            active ? "bg-surface-raised text-text1" : muted ? "text-text3" : "text-text2 hover:bg-surface-raised hover:text-text1",
          );
          if (item.locked) {
            return <div key={item.label} className={cn(cls, "cursor-not-allowed")} title={item.tooltip} aria-disabled>{content}</div>;
          }
          return (
            <Link key={item.label} href={item.href} className={cls} title={item.tooltip} aria-current={active ? "page" : undefined}>
              {content}
            </Link>
          );
        })}
      </nav>

      <div className="mt-auto border-t border-border p-4">
        {!collapsed && (
          <div className="mb-3">
            <p className="t-eyebrow text-text3">SIGNED IN AS</p>
            <p className="mt-1 truncate t-body-sm text-text2">{email}</p>
          </div>
        )}
        <form action={signOut}>
          <button
            type="submit" title={collapsed ? "Sign out" : undefined}
            className={cn("flex h-11 w-full items-center gap-2.5 rounded-btn bg-surface-raised px-3 text-text1 hover:brightness-110 cursor-pointer", collapsed && "justify-center")}
          >
            <SignOut size={18} aria-hidden />
            {!collapsed && <span className="t-label">SIGN OUT</span>}
          </button>
        </form>
      </div>
    </aside>
  );
}
```

- [ ] **Step 2: `components/admin/topbar.tsx`**

```tsx
"use client";
import { usePathname } from "next/navigation";
import { titleForPath } from "@/lib/admin/nav";

export function Topbar({ trailing }: { trailing?: React.ReactNode }) {
  const pathname = usePathname();
  return (
    <header className="flex h-16 shrink-0 items-center justify-between border-b border-border bg-background px-6 laptop:px-10">
      <h1 className="truncate t-title-lg text-text1">{titleForPath(pathname)}</h1>
      {trailing ? <div className="flex items-center gap-4">{trailing}</div> : null}
    </header>
  );
}
```

- [ ] **Step 3: `app/(admin)/layout.tsx`** (server shell)

```tsx
import { redirect } from "next/navigation";
import { getAdminSession } from "@/lib/auth";
import { Sidebar } from "@/components/admin/sidebar";
import { Topbar } from "@/components/admin/topbar";

/** Belt-and-braces: middleware already gates, but never render the shell
 *  for a non-admin if middleware is somehow bypassed. */
export default async function AdminLayout({ children }: { children: React.ReactNode }) {
  const session = await getAdminSession();
  if (!session) redirect("/login");

  return (
    <div className="flex h-dvh overflow-hidden">
      <Sidebar email={session.email} />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />
        <main className="flex-1 overflow-y-auto bg-background p-6 laptop:p-10">{children}</main>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Move the showcase into the gated group**

```bash
git -C /Users/kuya/Documents/Jobdun/admin-web mv app/page.tsx app/\(admin\)/page.tsx
```
Then edit the moved `app/(admin)/page.tsx`: it currently wraps content in `<main className="mx-auto ... p-8">` — the shell already provides `<main>` + padding, so change its outer `<main ...>` to `<div className="mx-auto flex max-w-5xl flex-col gap-8">` (remove the now-duplicate `p-8`/`main`). Leave the rest as-is (temporary; replaced by the real dashboard in P2).

- [ ] **Step 5: Commit (or hand to integration).** `git add -A && git commit -m "feat: admin shell (collapsible sidebar + topbar + gated layout)"`

---

## Task 6: Integration, verify, deploy  *(Stage C — orchestrator)*

- [ ] **Step 1: If Stage B agents didn't commit, commit their files** grouped as in Tasks 3–5.

- [ ] **Step 2: Full local gate.** Run: `npm run test && npm run lint && npm run build`
Expected: tests green (auth + redirect + P0 suites); lint clean; build compiles, TypeScript clean. **If `server-only` breaks the middleware/edge build**, apply the Task-2 Step-5 note (move `isAdminClaims`/`ADMIN_ROLE` to `lib/admin/redirect.ts`, re-export from `lib/auth.ts`) and rebuild.

- [ ] **Step 3: axe the login page.** Start the prod server, run axe against `/login` (it redirects `/` → `/login` when signed out, so `/login` is the reachable page):
```bash
npm start >/tmp/admin-p1.log 2>&1 & SRV=$!
curl --retry 25 --retry-delay 1 --retry-connrefused -sf -o /dev/null http://localhost:3000/login && echo up
AXE_ROUTES=/login npm run axe ; AX=$?
kill $SRV 2>/dev/null; pkill -f next-server 2>/dev/null; echo "AXE=$AX"
```
Expected: `/login` 0 violations.

- [ ] **Step 4: Local gate smoke (unauthenticated redirect).** With the server running, `curl -sS -o /dev/null -w "%{http_code} %{redirect_url}\n" http://localhost:3000/` → expect a 307/308 to `/login` (the middleware gate). Confirms anon is bounced.

- [ ] **Step 5: Set the Supabase env vars on Vercel** (production + preview + development):
```bash
cd /Users/kuya/Documents/Jobdun/admin-web
printf '%s' "$NEXT_PUBLIC_SUPABASE_URL" | vercel env add NEXT_PUBLIC_SUPABASE_URL production
# repeat for preview, development, and NEXT_PUBLIC_SUPABASE_ANON_KEY
```
(Use the real values from `.env.local`. Or set them in the Vercel dashboard → Project → Settings → Environment Variables. Both `NEXT_PUBLIC_*` vars, all three environments.)

- [ ] **Step 6: Push + deploy.** `git push -u origin main` then `vercel deploy --prod --cwd /Users/kuya/Documents/Jobdun/admin-web --yes`.

- [ ] **Step 7: Verify live.** `curl -sS -o /dev/null -w "%{http_code}\n" https://jobdun-admin-web.vercel.app/login` → 200; `curl` to `/` → redirect to `/login`. Then the USER does the real admin sign-in smoke (we don't have the password): sign in → lands on the gated dashboard shell; a non-admin account is rejected with "This account does not have admin access."

---

## Phase 1 Done-When

- Unauthenticated requests to any `(admin)` route are bounced to `/login` (server-side, no flash); an admin session reaches the shell; sign-out returns to `/login`.
- `/login` renders the split brand/form layout with the exact copy; client validation shows the exact field errors; bad creds + non-admin show the right banner.
- Sidebar collapses (auto <1024px + manual toggle), highlights the active route, shows the signed-in email + SIGN OUT; topbar shows the route title.
- `test` + `lint` + `build` green; `/login` axe 0; deployed to `jobdun-admin-web.vercel.app` with env vars set.

---

## Self-Review (against the spec's P1 row)

- **Spec P1 deliverables** — `@supabase/ssr` server/client/middleware ✓ (T1); root middleware `user_role` gate with the exact matrix ✓ (T2); `/login` split layout + server action + RHF validation + exact copy ✓ (T3); collapsible sidebar (240/72, auto-collapse, active, session email, sign-out) + topbar + `(admin)` group + server guard ✓ (T4–T5); no client-flash (server redirect) ✓.
- **Placeholder scan** — no TBD; every file has complete code; pure-logic tests (isAdminClaims, adminRedirect, zod schema) are real.
- **Type consistency** — `createClient` server vs browser kept in separate modules; `isAdminClaims(claims)` signature consistent across `lib/auth.ts`, middleware, and the login action; `NavItem`/`titleForPath` consistent; `Icon` type imported from `@phosphor-icons/react` root (P0 gotcha honored); colors = P0 tokens only; typography = `.t-*` ramp (Oswald/Open Sans NOT reintroduced).
- **Deferred** — password show/hide is included; the topbar per-page trailing actions (e.g. dashboard Refresh) arrive with their pages in P2+. Real admin sign-in smoke needs the user's credentials (noted in T6 Step 7).
