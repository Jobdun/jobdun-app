#!/usr/bin/env node
/**
 * capture_ui_handoff.mjs — sweep every Jobdun app screen and write a labelled
 * screenshot set for a design handoff.
 *
 * Why the web build and not a device farm: Jobdun is ONE Flutter entrypoint
 * (lib/main.dart) shipped to iOS, Android and app.jobdun.com.au. At a given
 * logical viewport the widget tree lays out identically on all three, so a
 * Chromium pass at 390x844 IS the iPhone layout — and it is scriptable,
 * deterministic and re-runnable, which a manual device pass is not.
 * Native chrome (status bar, safe areas, iOS sheet physics) is covered
 * separately by the real-device sets in 03-SCREENS/real-device-*.
 *
 * Prereqs:
 *   1. A web build pointed at STAGING. Note that the bundled `.env` asset
 *      out-ranks --dart-define (see core/config/env.dart), so the env must be
 *      swapped for the build, not passed on the command line:
 *
 *        cp .env /tmp/env.bak
 *        sed -e 's|^SUPABASE_URL=.*|SUPABASE_URL=<staging url>|' \
 *            -e 's|^SUPABASE_ANON_KEY=.*|SUPABASE_ANON_KEY=<staging anon>|' \
 *            /tmp/env.bak > .env
 *        flutter build web --release --output=/tmp/web-staging
 *        cp /tmp/env.bak .env        # ALWAYS restore
 *
 *   2. Serve it:  python3 -m http.server 8899 --directory /tmp/web-staging
 *
 * Run:
 *   node scripts/capture_ui_handoff.mjs --out <dir> [--pass ios-dark,...]
 *
 * Credentials are staging-only QA fixtures (docs/STAGING_BACKEND.md).
 */

// Playwright is not a root dependency of this Flutter repo — it comes in with
// admin-web/ (and marketing-site/). Resolve it from there so the script runs
// from the repo root with no extra install step.
const { chromium } = await (async () => {
  for (const spec of [
    'playwright',
    new URL('../admin-web/node_modules/playwright/index.mjs', import.meta.url).href,
    new URL('../marketing-site/node_modules/playwright/index.mjs', import.meta.url).href,
  ]) {
    try { return await import(spec); } catch { /* try next */ }
  }
  throw new Error('playwright not found — run `npm i` in admin-web/ or marketing-site/');
})();
import { createHash } from 'node:crypto';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const BASE = process.env.HANDOFF_BASE_URL ?? 'http://localhost:8899';
const OUT = argOf('--out') ?? './handoff-screens';
const ONLY = (argOf('--pass') ?? '').split(',').filter(Boolean);
// --routes accepts id prefixes, e.g. --routes 02,03,23 to re-shoot a few screens
const ONLY_ROUTES = (argOf('--routes') ?? '').split(',').filter(Boolean);

function argOf(flag) {
  const i = process.argv.indexOf(flag);
  return i > -1 ? process.argv[i + 1] : null;
}

const ACCOUNTS = {
  builder: { email: 'qa.builder.test@jobdun.com.au', password: '123Jobdun!' },
  trade: { email: 'qa.trade.test@jobdun.com.au', password: '123Jobdun!' },
};

// Staging project + anon key (client-safe, and already published in
// docs/STAGING_BACKEND.md). Override via env to point at a different backend.
const SUPABASE_URL = process.env.HANDOFF_SUPABASE_URL
  ?? 'https://kqpsceobwtavcxhatxww.supabase.co';
const SUPABASE_ANON = process.env.HANDOFF_SUPABASE_ANON ?? '';

/** Ids resolved from the backend at start-up so deep links hit real rows. */
const FIXTURES = { jobId: null };

async function loadFixtures() {
  if (!SUPABASE_ANON) {
    console.log('· HANDOFF_SUPABASE_ANON not set — job detail will be skipped');
    return;
  }
  try {
    const auth = await fetch(`${SUPABASE_URL}/auth/v1/token?grant_type=password`, {
      method: 'POST',
      headers: { apikey: SUPABASE_ANON, 'Content-Type': 'application/json' },
      body: JSON.stringify(ACCOUNTS.trade),
    }).then((r) => r.json());
    if (!auth.access_token) throw new Error('auth failed');
    const jobs = await fetch(
      `${SUPABASE_URL}/rest/v1/jobs?select=id,title&status=eq.open&title=not.ilike.*QA%20TEST*&order=created_at.asc&limit=1`,
      { headers: { apikey: SUPABASE_ANON, Authorization: `Bearer ${auth.access_token}` } },
    ).then((r) => r.json());
    if (Array.isArray(jobs) && jobs[0]) {
      FIXTURES.jobId = jobs[0].id;
      console.log(`· job detail will deep-link to "${jobs[0].title}"`);
    }
  } catch (e) {
    console.log('· could not resolve fixtures:', String(e).slice(0, 100));
  }
}

/**
 * Every route reachable in the app, in journey order.
 *
 * `roles` — which session the screen is captured under.
 *
 * Most routes deep-link straight from the URL. The exceptions are routes that
 * read `state.extra`: GoRouter falls back to the list page when it is null, so
 * those need `from` + `tapYFrac` to be opened by tapping a row instead.
 * Job detail is NOT one of them — it falls through to a loader that fetches by
 * id, so it deep-links fine.
 */
const ROUTES = [
  // ── Guest / pre-auth ────────────────────────────────────────────────────
  { id: '01-splash', path: '/splash', roles: ['guest'], name: 'Splash', settle: 2500 },
  { id: '02-ftue-slide-1', path: '/ftue', roles: ['guest'], name: 'FTUE — slide 1 (Only verified)' },
  { id: '03-ftue-slide-2', path: '/ftue', roles: ['guest'], name: 'FTUE — slide 2', swipes: 1 },
  { id: '04-ftue-slide-3', path: '/ftue', roles: ['guest'], name: 'FTUE — slide 3 (role picker)', swipes: 2 },
  { id: '05-login', path: '/login', roles: ['guest'], name: 'Log in — empty' },
  { id: '06-login-validation', path: '/login', roles: ['guest'], name: 'Log in — validation errors', act: 'loginValidation' },
  { id: '07-register-role-picker', path: '/register', roles: ['guest'], name: 'Create account — role picker' },
  { id: '08-register-builder', path: '/register?role=builder', roles: ['guest'], name: 'Create account — builder form' },
  { id: '09-register-trade', path: '/register?role=trade', roles: ['guest'], name: 'Create account — trade form' },
  { id: '10-forgot-password', path: '/forgot-password', roles: ['guest'], name: 'Forgot password' },
  { id: '11-phone-auth', path: '/phone-auth', roles: ['guest'], name: 'Phone sign-in (OTP)' },
  { id: '12-verify-email', path: '/verify-email', roles: ['guest'], name: 'Verify email' },
  { id: '13-browse-guest', path: '/browse', roles: ['guest'], name: 'Browse jobs — guest (no session)' },
  { id: '14-legal-index', path: '/legal', roles: ['guest'], name: 'Legal index' },
  { id: '15-legal-terms', path: '/legal/terms', roles: ['guest'], name: 'Terms of service' },
  { id: '16-legal-privacy', path: '/legal/privacy', roles: ['guest'], name: 'Privacy policy' },

  // ── Shell tabs ──────────────────────────────────────────────────────────
  { id: '20-home', path: '/home', roles: ['builder', 'trade'], name: 'Home (tab 1)' },
  { id: '21-jobs', path: '/jobs', roles: ['builder', 'trade'], name: 'Jobs feed (tab 2)' },
  { id: '22-jobs-map', path: '/jobs/map', roles: ['builder', 'trade'], name: 'Jobs map', settle: 6000 },
  // Job detail IS deep-linkable: with no `extra`, the route falls through to
  // JobDetailLoaderPage, which fetches by id. `:jobId` is substituted at run
  // time from the staging fixtures.
  { id: '23-job-detail', path: '/jobs/:jobId', roles: ['builder', 'trade'], name: 'Job detail', settle: 6000 },
  // Applicants-for-a-job needs `extra`, so it is opened by tapping the first
  // row of the builder's own listings (which sit just under the filter chips).
  { id: '23b-job-applicants', roles: ['builder'], name: 'Applicants for a job', from: '/jobs', tapYFrac: 0.26 },
  { id: '24-job-create', path: '/jobs/create', roles: ['builder'], name: 'Post a job (single long form)' },
  { id: '25-applications', path: '/applications', roles: ['builder', 'trade'], name: 'Applications (tab 3)' },
  { id: '26-messages', path: '/messages', roles: ['builder', 'trade'], name: 'Messages inbox (tab 4)' },
  // The thread route needs `extra`, so it cannot be deep-linked — it has to be
  // opened by tapping the inbox row. That row always sits directly under the
  // header, hence the fixed fraction of viewport height.
  { id: '27-message-thread', roles: ['builder', 'trade'], name: 'Message thread', from: '/messages', tapYFrac: 0.14 },

  // ── Discovery ───────────────────────────────────────────────────────────
  { id: '30-discovery', path: '/discovery', roles: ['builder'], name: 'Find tradies — directory' },
  { id: '31-discovery-map', path: '/discovery/map', roles: ['builder'], name: 'Find tradies — map', settle: 6000 },

  // ── Profile / account ───────────────────────────────────────────────────
  { id: '40-profile', path: '/profile', roles: ['builder', 'trade'], name: 'My profile' },
  { id: '41-profile-edit', path: '/profile/edit', roles: ['builder', 'trade'], name: 'Edit profile — section hub' },
  { id: '42-profile-edit-about', path: '/profile/edit/about', roles: ['builder', 'trade'], name: 'Edit profile — about (full editor)' },
  { id: '43-verification', path: '/verification', roles: ['builder', 'trade'], name: 'Verification status' },
  { id: '44-verification-wizard', path: '/verification/wizard', roles: ['builder', 'trade'], name: 'Verification wizard' },
  { id: '45-reviews', path: '/reviews', roles: ['builder', 'trade'], name: 'Reviews' },

  // ── Utility ─────────────────────────────────────────────────────────────
  { id: '50-notifications', path: '/notifications', roles: ['builder', 'trade'], name: 'Notifications' },
  { id: '51-settings', path: '/settings', roles: ['builder', 'trade'], name: 'Settings' },
  { id: '52-settings-notifications', path: '/settings/notifications', roles: ['builder', 'trade'], name: 'Settings — notifications' },
  { id: '53-settings-availability', path: '/settings/availability', roles: ['trade', 'builder'], name: 'Settings — availability calendar' },
  { id: '54-quotes', path: '/quotes', roles: ['builder', 'trade'], name: 'Quote requests inbox' },
  { id: '55-schedule', path: '/schedule', roles: ['builder', 'trade'], name: 'Schedule / bookings' },
];

const PASSES = [
  { id: 'ios-dark', width: 390, height: 844, dpr: 3, scheme: 'dark', touch: true, roles: ['guest', 'builder', 'trade'] },
  { id: 'ios-light', width: 390, height: 844, dpr: 3, scheme: 'light', touch: true, roles: ['guest', 'builder'] },
  { id: 'android-dark', width: 412, height: 915, dpr: 2, scheme: 'dark', touch: true, roles: ['guest', 'builder', 'trade'] },
  { id: 'webapp-desktop-dark', width: 1440, height: 900, dpr: 2, scheme: 'dark', roles: ['guest', 'builder'] },
  { id: 'webapp-desktop-light', width: 1440, height: 900, dpr: 2, scheme: 'light', roles: ['builder'] },
];

const sha = (buf) => createHash('sha1').update(buf).digest('hex');

async function boot(page, hash, settle = 4200) {
  await page.goto(`${BASE}/#${hash}`, { waitUntil: 'load' });
  // A hash-only change is a same-document navigation, so force a real reload
  // to make GoRouter rebuild from the URL. The session lives in localStorage
  // (sb-<ref>-auth-token) and survives it.
  await page.reload({ waitUntil: 'load' });
  await page.waitForTimeout(settle);
}

async function login(page, role, vp) {
  for (let attempt = 1; attempt <= 3; attempt++) {
    if (await loginOnce(page, role, vp)) return true;
    if (attempt < 3) console.log(`      · retrying login as ${role} (attempt ${attempt + 1}/3)`);
  }
  console.log(`      ! login as ${role} FAILED after 3 attempts — skipping this role`);
  return false;
}

async function loginOnce(page, role, vp) {
  const { email, password } = ACCOUNTS[role];
  await boot(page, '/login', 6500);

  // Flutter renders to a canvas, so the fields have no stable DOM. Turning on
  // semantics briefly materialises real <input> elements; their geometry is
  // read once and then driven by pointer + keyboard. Coordinates must NOT be
  // hardcoded — the layout shifts between viewport sizes.
  await enableSemantics(page);
  let fields = [];
  for (let i = 0; i < 14 && fields.length < 2; i++) {
    fields = await page.evaluate(() =>
      [...document.querySelectorAll('input')].map((el) => {
        const r = el.getBoundingClientRect();
        return { type: el.type, x: Math.round(r.x + r.width / 2), y: Math.round(r.y + r.height / 2) };
      }));
    if (fields.length < 2) await page.waitForTimeout(700);
  }

  const emailBox = fields.find((f) => f.type === 'text') ?? fields[0];
  const passBox = fields.find((f) => f.type === 'password') ?? fields[1];
  if (!emailBox || !passBox) {
    // Deliberately do NOT guess coordinates here. Guessing produced screenshots
    // of the login screen filed under `20-home-builder`, which is worse than no
    // screenshot. Fail and let the caller retry from a fresh page load.
    console.log(`      · login as ${role}: form fields not in the semantics tree yet`);
    return false;
  }

  await page.mouse.click(emailBox.x, emailBox.y);
  await page.waitForTimeout(500);
  await page.keyboard.type(email, { delay: 10 });
  await page.mouse.click(passBox.x, passBox.y);
  await page.waitForTimeout(500);
  await page.keyboard.type(password, { delay: 10 });
  await page.waitForTimeout(400);

  // The submit button sits below the password field, past the "Don't have an
  // account?" row. Its offset scales with the field gap, but an inline error
  // banner can push it down — so try a few positions and stop once the router
  // has actually left /login.
  // Confirm the keystrokes actually landed before submitting — a click that
  // misses the field leaves an empty form and the submit looks like a failure
  // for the wrong reason.
  const typed = await page.evaluate(() =>
    [...document.querySelectorAll('input')].map((el) => el.value.length));
  if (!typed.some((n) => n > 5)) {
    console.log(`      · login as ${role}: text did not reach the field`);
    return false;
  }

  // The submit button sits below the password field, past the "Don't have an
  // account?" row. Its offset scales with the field gap, but an inline error
  // banner can push it down — so try a few positions. Success is specifically
  // landing on /home: any other navigation means we hit the wrong control
  // (Create account, Browse jobs, an SSO button) and must not count.
  const gap = passBox.y - emailBox.y;
  for (const k of [1.19, 0.95, 1.45]) {
    await page.mouse.click(passBox.x, Math.round(passBox.y + gap * k));
    await page.waitForTimeout(6500);
    if (page.url().includes('/home')) return true;
    if (!page.url().includes('/login')) return false;   // wandered off — restart clean
  }
  console.log(`      · login as ${role} did not reach /home (url=${page.url()})`);
  return false;
}

/**
 * Turn on Flutter web's semantics tree. Flutter renders into a canvas, so
 * there is normally no DOM to target; clicking the hidden "Enable
 * accessibility" placeholder makes it mirror the widget tree into real
 * <flt-semantics> nodes that Playwright can measure and click.
 */
async function enableSemantics(page, minNodes = 4) {
  // The placeholder only exists until it is clicked, and the tree then
  // populates on its own schedule — so poll for real nodes rather than
  // assuming a fixed delay. This flakiness is what previously broke both
  // login and row-tapping on some passes.
  for (let i = 0; i < 12; i++) {
    const n = await page.evaluate(() => document.querySelectorAll('flt-semantics').length);
    if (n >= minNodes) return true;
    const ph = await page.$('flt-semantics-placeholder, [aria-label="Enable accessibility"]');
    if (ph) await ph.evaluate((e) => e.click());
    await page.waitForTimeout(700);
  }
  return false;
}

/**
 * Advance a Flutter `PageView` one page (the FTUE carousel).
 *
 * A synthetic mouse drag does NOT move it — Flutter's gesture arena never
 * claims the drag — and a horizontal wheel does nothing either. Raw CDP touch
 * events are what work, which also means the context must be touch-enabled.
 */
async function swipeLeft(page, cdp, vp) {
  if (!cdp) return;
  const y = Math.round(vp.height * 0.5);
  const from = Math.round(vp.width * 0.87);
  const to = Math.round(vp.width * 0.15);
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchStart', touchPoints: [{ x: from, y }] });
  for (let x = from; x >= to; x -= 28) {
    await cdp.send('Input.dispatchTouchEvent', { type: 'touchMove', touchPoints: [{ x, y }] });
    await page.waitForTimeout(16);
  }
  await cdp.send('Input.dispatchTouchEvent', { type: 'touchEnd', touchPoints: [] });
  await page.waitForTimeout(1600);
}

/**
 * Capture the viewport, then scroll and capture again while the frame keeps
 * changing — Flutter renders into a viewport-sized canvas, so Playwright's
 * fullPage option cannot see below the fold.
 */
async function captureWithScroll(page, dir, base, label, manifest, meta) {
  const shots = [];
  let prev = null;
  for (let i = 0; i < 4; i++) {
    if (i > 0) {
      await page.mouse.move(200, 400);
      await page.mouse.wheel(0, Math.round(page.viewportSize().height * 0.8));
      await page.waitForTimeout(1400);
    }
    const buf = await page.screenshot();
    const h = sha(buf);
    if (h === prev) break;
    prev = h;
    const suffix = i === 0 ? '' : `-scroll${i}`;
    const file = `${base}${suffix}.png`;
    writeFileSync(join(dir, file), buf);
    shots.push(file);
  }
  manifest.push({ ...meta, label, files: shots });
  return shots.length;
}

async function runPass(browser, pass) {
  const dir = join(OUT, pass.id);
  mkdirSync(dir, { recursive: true });
  const manifest = [];
  console.log(`\n=== pass ${pass.id} (${pass.width}x${pass.height} @${pass.dpr}x, ${pass.scheme}) ===`);

  for (const role of pass.roles) {
    const ctx = await browser.newContext({
      viewport: { width: pass.width, height: pass.height },
      deviceScaleFactor: pass.dpr,
      colorScheme: pass.scheme,
      reducedMotion: 'reduce',
      hasTouch: !!pass.touch,
    });
    const page = await ctx.newPage();
    page.on('pageerror', (e) => console.log('      [pageerror]', String(e).slice(0, 120)));
    const cdp = pass.touch ? await ctx.newCDPSession(page) : null;

    if (role !== 'guest') {
      const ok = await login(page, role, pass);
      if (!ok) { await ctx.close(); continue; }
    }

    for (const r of ROUTES) {
      if (!r.roles.includes(role)) continue;
      if (ONLY_ROUTES.length && !ONLY_ROUTES.some((p) => r.id.startsWith(p))) continue;
      if (r.path?.includes(':jobId') && !FIXTURES.jobId) {
        console.log(`      · skipping ${r.id} — no fixture job id resolved`);
        continue;
      }
      const base = `${r.id}-${role}`;
      try {
        if (r.from) {
          await boot(page, r.from, r.settle ?? 4200);
          await page.mouse.click(Math.round(pass.width / 2), Math.round(pass.height * r.tapYFrac));
          await page.waitForTimeout(5000);
        } else {
          await boot(page, r.path.replace(':jobId', FIXTURES.jobId ?? ''), r.settle ?? 4200);
        }

        if (r.swipes) {
          for (let s = 0; s < r.swipes; s++) await swipeLeft(page, cdp, pass);
        }

        if (r.act === 'loginValidation') {
          await page.mouse.click(Math.round(pass.width / 2), pass.width > 700 ? 536 : 446);
          await page.waitForTimeout(1600);
        }

        const n = await captureWithScroll(page, dir, base, r.name, manifest, {
          id: r.id, role, route: r.path ?? `${r.from} → tap`, pass: pass.id,
        });
        console.log(`  ${base}  (${n} frame${n === 1 ? '' : 's'})`);
      } catch (e) {
        console.log(`  ! ${base} FAILED: ${String(e).slice(0, 140)}`);
      }
    }
    await ctx.close();
  }

  writeFileSync(join(dir, '_manifest.json'), JSON.stringify(manifest, null, 2));
  return manifest;
}

await loadFixtures();
const browser = await chromium.launch();
const all = {};
for (const pass of PASSES) {
  if (ONLY.length && !ONLY.includes(pass.id)) continue;
  all[pass.id] = await runPass(browser, pass);
}
await browser.close();
mkdirSync(OUT, { recursive: true });
writeFileSync(join(OUT, '_all-manifest.json'), JSON.stringify(all, null, 2));
const total = Object.values(all).flat().reduce((n, m) => n + m.files.length, 0);
console.log(`\nDONE — ${total} PNGs across ${Object.keys(all).length} passes → ${OUT}`);
