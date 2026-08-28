#!/usr/bin/env node
/**
 * organize_ui_handoff_figma.mjs — re-file the raw capture output from
 * `capture_ui_handoff.mjs` into the shape a designer actually opens.
 *
 * The capture script writes by *capture pass* (ios-dark/, android-dark/, …)
 * because that is how the browser sessions run. That is the wrong axis for a
 * handoff: Timothy works one Figma page at a time, and a Jobdun page is a
 * ROLE (builder / trade / guest), not a device. Device + theme belong in the
 * frame NAME, which is also how his existing files are named:
 *
 *     Cookie Policy — Desktop (1440)
 *
 * So this script inverts the tree:
 *
 *     <pass>/<id>-<role>[-scrollN].png
 *       ->  <NN-ROLE-PAGE>/<NN> <Screen Name> — <Device> (<w>)[ <frame>].png
 *
 * One output folder = one Figma page. Select-all inside it, drag into Figma,
 * and every frame arrives correctly named and in journey order.
 *
 * Idempotent-ish: it MOVES files, so run it once on a fresh capture. The
 * pre-reorg state is recoverable from JOBDUN-UI-HANDOFF.zip or by re-running
 * capture_ui_handoff.mjs.
 *
 * Run:
 *   node scripts/organize_ui_handoff_figma.mjs                 # dry run
 *   node scripts/organize_ui_handoff_figma.mjs --apply         # do it
 *   node scripts/organize_ui_handoff_figma.mjs --root <dir>
 */

import { existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, rmdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const argOf = (f) => { const i = process.argv.indexOf(f); return i > -1 ? process.argv[i + 1] : null; };
const APPLY = process.argv.includes('--apply');
const ROOT = argOf('--root') ?? 'JOBDUN-UI-HANDOFF/03-SCREENS';

/** Capture pass -> the device label that goes in the frame name. */
const DEVICE = {
  'ios-dark': 'iOS Dark (390)',
  'ios-light': 'iOS Light (390)',
  'android-dark': 'Android Dark (412)',
  'webapp-desktop-dark': 'Desktop Dark (1440)',
  'webapp-desktop-light': 'Desktop Light (1440)',
};

/**
 * Route id -> the human name of the screen.
 *
 * Taken from the `name` field in capture_ui_handoff.mjs, but with the em dash
 * removed: " — " is the frame-name separator between screen and device, so a
 * screen name containing one would produce an unparseable frame title.
 */
const SCREEN = {
  '01-splash': 'Splash',
  '02-ftue-slide-1': 'FTUE Slide 1 · Only Verified',
  '03-ftue-slide-2': 'FTUE Slide 2',
  '04-ftue-slide-3': 'FTUE Slide 3 · Role Picker',
  '05-login': 'Log In',
  '06-login-validation': 'Log In · Validation Errors',
  '07-register-role-picker': 'Create Account · Role Picker',
  '08-register-builder': 'Create Account · Builder Form',
  '09-register-trade': 'Create Account · Trade Form',
  '10-forgot-password': 'Forgot Password',
  '11-phone-auth': 'Phone Sign-in · OTP',
  '12-verify-email': 'Verify Email',
  '13-browse-guest': 'Browse Jobs · No Session',
  '14-legal-index': 'Legal Index',
  '15-legal-terms': 'Terms of Service',
  '16-legal-privacy': 'Privacy Policy',
  '20-home': 'Home · Tab 1',
  '21-jobs': 'Jobs Feed · Tab 2',
  '22-jobs-map': 'Jobs Map',
  '23-job-detail': 'Job Detail',
  '23b-job-applicants': 'Applicants for a Job',
  '24-job-create': 'Post a Job',
  '25-applications': 'Applications · Tab 3',
  '26-messages': 'Messages Inbox · Tab 4',
  '27-message-thread': 'Message Thread',
  '30-discovery': 'Find Tradies · Directory',
  '31-discovery-map': 'Find Tradies · Map',
  '40-profile': 'My Profile',
  '41-profile-edit': 'Edit Profile · Section Hub',
  '42-profile-edit-about': 'Edit Profile · About',
  '43-verification': 'Verification Status',
  '44-verification-wizard': 'Verification Wizard',
  '45-reviews': 'Reviews',
  '50-notifications': 'Notifications',
  '51-settings': 'Settings',
  '52-settings-notifications': 'Settings · Notifications',
  '53-settings-availability': 'Settings · Availability',
  '54-quotes': 'Quote Requests',
  '55-schedule': 'Schedule & Bookings',
};

/** Output folders, in the order they should be created as Figma pages. */
const PAGES = {
  guest: '01-GUEST-AND-AUTH',
  builder: '02-BUILDER',
  trade: '03-TRADE',
  deviceBuilder: '04-REAL-DEVICE-BUILDER-ANDROID',
  deviceTrade: '05-REAL-DEVICE-TRADE-IPHONE',
  desktop: '06-DESKTOP-WEB-CONTEXT',
};

/** Real-device sets have no manifest, so their names are mapped by hand. */
const REAL_ANDROID = {
  '01_ftue_splash': ['01', 'Guest · FTUE Splash'],
  '02_ftue_page2': ['02', 'Guest · FTUE Slide 2'],
  '03_ftue_page3': ['03', 'Guest · FTUE Slide 3'],
  '04_role_picker': ['04', 'Guest · Role Picker'],
  '05_login': ['05', 'Guest · Log In'],
  '06_login_filled': ['06', 'Guest · Log In Filled'],
  '07_builder_home': ['07', 'Home'],
  '08_wizard_step1': ['08', 'Post a Job · Step 1'],
  '09_wizard_step1_filled': ['09', 'Post a Job · Step 1 Filled'],
  '10_wizard_step2': ['10', 'Post a Job · Step 2'],
  '11_wizard_resume_draft_sheet': ['11', 'Post a Job · Resume Draft Sheet'],
  '12_my_jobs': ['12', 'My Jobs'],
  '13_applicants': ['13', 'Applicants'],
  '14_messages': ['14', 'Messages'],
  '15_you_account_sheet': ['15', 'Account Sheet'],
  '17_builder_home_with_applicant': ['17', 'Home with Applicant'],
  '18_edit_profile': ['18', 'Edit Profile'],
  '19_builder_profile': ['19', 'Builder Profile'],
  '20_applicants_job_view': ['20', 'Applicants · Job View'],
  '21_applicants_list': ['21', 'Applicants · List'],
  '22_applicant_detail': ['22', 'Applicant Detail 1'],
  '22_applicant_detail_scrolled': ['22', 'Applicant Detail 2'],
  '23_shortlisted': ['23', 'Shortlisted'],
  '24_applicant_detail_with_hire': ['24', 'Applicant Detail · Hire CTA'],
  '25_hire_confirmation_sheet': ['25', 'Hire Confirmation Sheet'],
  '26_hire_celebration': ['26', 'Hire Celebration'],
  '27_builder_home_after_hire': ['27', 'Home After Hire'],
  '28_my_jobs_filled': ['28', 'My Jobs · Filled'],
  '29_applicants_for_filled_job': ['29', 'Applicants for Filled Job'],
  '30_hired_applicant_filled': ['30', 'Hired Applicant'],
};

const REAL_IOS = {
  '01-home-trade-LIGHT': ['01', 'Home', 'Light'],
  '02-find-jobs-feed-LIGHT': ['02', 'Jobs Feed', 'Light'],
  '03-messages-inbox-LIGHT': ['03', 'Messages Inbox', 'Light'],
  '04-account-sheet-LIGHT': ['04', 'Account Sheet', 'Light'],
  '05-profile-trade-LIGHT': ['05', 'My Profile', 'Light'],
  '06-settings-darkmode-toggle-DARK': ['06', 'Settings · Dark Mode Toggle', 'Dark'],
  '07-login-DARK': ['07', 'Guest · Log In', 'Dark'],
  '08-login-error-apple-sheet-DARK': ['08', 'Guest · Log In Error + Apple Sheet', 'Dark'],
  '09-ftue-slide-1-DARK': ['09', 'Guest · FTUE Slide 1', 'Dark'],
  '10-applied-track-status-DARK': ['10', 'Applied · Track Status', 'Dark'],
};

// ── build the plan ────────────────────────────────────────────────────────
// The plan is derived from the capture manifests, not from a directory listing,
// so it is identical whether the files have been moved yet or not. That makes
// the script safe to re-run: an already-filed screenshot is simply skipped.

const plan = [];      // { from, to, page, id, role, route, label, frame, of }
const problems = [];

const readJson = (p) => JSON.parse(readFileSync(p, 'utf8'));

/** Manifests start beside their captures and end up in `_manifests/`. */
function manifestPath(pass) {
  const moved = join(ROOT, '_manifests', `${pass}.json`);
  const original = join(ROOT, pass, '_manifest.json');
  return existsSync(moved) ? moved : existsSync(original) ? original : null;
}

for (const pass of Object.keys(DEVICE)) {
  const mp = manifestPath(pass);
  if (!mp) { problems.push(`no manifest for pass: ${pass}`); continue; }

  for (const entry of readJson(mp)) {
    if (!SCREEN[entry.id]) { problems.push(`unknown route id: ${pass}/${entry.id}`); continue; }
    const isDesktop = pass.startsWith('webapp-');
    const page = isDesktop ? PAGES.desktop : PAGES[entry.role];
    // Role is the folder on the role-scoped pages, so repeating it in the frame
    // name is noise. On the mixed desktop page it is load-bearing.
    const roleTag = isDesktop ? `${entry.role[0].toUpperCase()}${entry.role.slice(1)} · ` : '';
    const step = entry.id.replace(/^(\d+[a-z]?)-.*/, '$1');
    const of = entry.files.length;

    entry.files.forEach((file, i) => {
      // `[1 of 3]` rather than a bare number: it says up front that more of this
      // screen exists below the fold, and it cannot be misread as part of the
      // screen name (several of which already end in a digit).
      const num = of > 1 ? ` [${i + 1} of ${of}]` : '';
      plan.push({
        from: join(ROOT, pass, file),
        to: join(ROOT, page, `${step} ${roleTag}${SCREEN[entry.id]} — ${DEVICE[pass]}${num}.png`),
        page, id: entry.id, role: entry.role, route: entry.route,
        label: SCREEN[entry.id], device: DEVICE[pass], frame: i + 1, of,
        manifest: pass, entry,
      });
    });
  }
}

for (const [stem, [n, name]] of Object.entries(REAL_ANDROID)) {
  plan.push({
    from: join(ROOT, 'real-device-android', `${stem}.png`),
    to: join(ROOT, PAGES.deviceBuilder, `${n} ${name} — Android Device.png`),
    page: PAGES.deviceBuilder, id: stem, role: 'builder', route: '(real device)',
    label: name, device: 'Android Device', frame: 1, of: 1,
  });
}

for (const [stem, [n, name, theme]] of Object.entries(REAL_IOS)) {
  plan.push({
    from: join(ROOT, 'real-device-ios-iphone17promax', `${stem}.png`),
    to: join(ROOT, PAGES.deviceTrade, `${n} ${name} — iPhone 17 Pro Max ${theme}.png`),
    page: PAGES.deviceTrade, id: stem, role: 'trade', route: '(real device)',
    label: name, device: `iPhone 17 Pro Max ${theme}`, frame: 1, of: 1,
  });
}

/** Loose docs that belong with the screens they describe. */
const DOC_MOVES = [
  ['real-device-android/README.md', `${PAGES.deviceBuilder}/README.md`],
  ['real-device-android/_ORIGINAL-MANIFEST.md', `${PAGES.deviceBuilder}/_ORIGINAL-MANIFEST.md`],
  ['real-device-ios-iphone17promax/README.md', `${PAGES.deviceTrade}/README.md`],
];
for (const pass of Object.keys(DEVICE)) {
  const mp = join(ROOT, pass, '_manifest.json');
  if (existsSync(mp)) DOC_MOVES.push([`${pass}/_manifest.json`, `_manifests/${pass}.json`]);
}

// The per-pass `index.md` files list the OLD filenames screen by screen. Once
// the frames are renamed they are actively misleading, and FRAME-INDEX.md now
// carries the same information, so they go.
const DOC_DELETES = Object.keys(DEVICE).map((p) => `${p}/index.md`);

// ── report ────────────────────────────────────────────────────────────────
const todo = plan.filter((m) => existsSync(m.from));
const done = plan.filter((m) => !existsSync(m.from) && existsSync(m.to));
const lost = plan.filter((m) => !existsSync(m.from) && !existsSync(m.to));
for (const m of lost) problems.push(`MISSING: ${m.from}`);

const collide = new Map();
for (const m of plan) collide.set(m.to, (collide.get(m.to) ?? 0) + 1);
for (const [to, n] of collide) if (n > 1) problems.push(`COLLISION (${n}x): ${to}`);

const byPage = plan.reduce((a, m) => ((a[m.page] = (a[m.page] ?? 0) + 1), a), {});
console.log(`${APPLY ? 'APPLYING' : 'DRY RUN —'} ${plan.length} frames · ${todo.length} to move · ${done.length} already filed\n`);
for (const p of Object.keys(PAGES).map((k) => PAGES[k])) {
  if (byPage[p]) console.log(`  ${String(byPage[p]).padStart(4)}  ${p}/`);
}
if (problems.length) {
  console.log(`\n! ${problems.length} problem(s):`);
  for (const p of problems) console.log(`  - ${p}`);
}

if (!APPLY) {
  console.log('\nSample frame names:');
  for (const m of plan.filter((m) => m.page === PAGES.builder).slice(0, 6)) console.log(`  ${m.page}/${m.to.split('/').pop()}`);
  console.log('\nRe-run with --apply.');
  process.exit(problems.some((p) => p.startsWith('COLLISION') || p.startsWith('MISSING')) ? 1 : 0);
}
if (problems.some((p) => p.startsWith('COLLISION'))) {
  console.error('\nRefusing to move: name collisions would destroy files.');
  process.exit(1);
}

// ── apply ─────────────────────────────────────────────────────────────────
for (const p of new Set([...plan.map((m) => m.page), '_manifests'])) mkdirSync(join(ROOT, p), { recursive: true });
for (const m of todo) renameSync(m.from, m.to);
console.log(`  moved ${todo.length} image(s)`);

for (const [from, to] of DOC_MOVES) {
  if (!existsSync(join(ROOT, from))) continue;
  mkdirSync(join(ROOT, to, '..'), { recursive: true });
  renameSync(join(ROOT, from), join(ROOT, to));
  console.log(`  moved ${from} -> ${to}`);
}
for (const f of DOC_DELETES) {
  if (existsSync(join(ROOT, f))) { rmSync(join(ROOT, f)); console.log(`  removed stale ${f}`); }
}

// Re-label the manifests so they describe the frames as they are now named.
const byManifest = new Map();
for (const m of plan.filter((m) => m.manifest)) {
  if (!byManifest.has(m.manifest)) byManifest.set(m.manifest, new Map());
  const g = byManifest.get(m.manifest);
  const k = `${m.id}|${m.role}`;
  if (!g.has(k)) g.set(k, { id: m.id, role: m.role, route: m.route, label: m.label, page: m.page, device: m.device, frames: [] });
  g.get(k).frames.push(m.to.split('/').pop());
}
for (const [pass, g] of byManifest) {
  writeFileSync(join(ROOT, '_manifests', `${pass}.json`), JSON.stringify([...g.values()], null, 2));
}
console.log(`  re-labelled ${byManifest.size} manifest(s)`);

// Drop the emptied capture-pass folders.
for (const pass of [...Object.keys(DEVICE), 'real-device-android', 'real-device-ios-iphone17promax']) {
  const dir = join(ROOT, pass);
  if (!existsSync(dir)) continue;
  const left = readdirSync(dir);
  if (left.length === 0) { rmdirSync(dir); console.log(`  removed empty ${pass}/`); }
  else console.log(`  ! ${pass}/ still holds ${left.length}: ${left.join(', ')}`);
}

// A flat index so any frame can be traced back to the route that produced it.
const PAGE_ORDER = Object.values(PAGES);
const rows = plan
  .sort((a, b) => PAGE_ORDER.indexOf(a.page) - PAGE_ORDER.indexOf(b.page)
    || a.to.localeCompare(b.to))
  .map((m) => `| \`${m.page}\` | ${m.to.split('/').pop().replace(/\.png$/, '')} | ${m.role} | \`${m.route}\` |`);
writeFileSync(join(ROOT, 'FRAME-INDEX.md'),
  '# Frame index\n\nEvery image in `03-SCREENS/`, in the order it appears on its Figma page.\n'
  + 'Generated by `scripts/organize_ui_handoff_figma.mjs` — do not hand-edit.\n\n'
  + `${plan.length} frames across ${Object.keys(byPage).length} pages.\n\n`
  + '| Page | Frame | Role | Route |\n|---|---|---|---|\n' + rows.join('\n') + '\n');

console.log(`\nDONE — ${plan.length} frames across ${Object.keys(byPage).length} pages.`);
