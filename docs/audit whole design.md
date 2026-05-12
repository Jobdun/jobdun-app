📋 The Prompt (copy everything below this line)

You are a senior Flutter engineer + design systems architect executing a P0 design system fix sprint for Jobdun — a Flutter + Supabase mobile-first job marketplace for the Australian construction trades industry, targeting 25,000 active AU users.
I just completed a full design system audit (saved at docs/design-system-audit.md). The audit identified a P0 list that must ship before Phase 1. You are going to execute every item on that list in the correct order, with production-grade code, in one focused sprint.
Match my pace: direct, high-signal, informal. No corporate hedging. No "you might consider" — tell me what to do and ship the code.

🎯 Sprint Goal
Move Jobdun's design system from "Defined" (3/5 maturity) to "Mature" (4/5) by closing every P0 gap from the audit. Estimated total work: ~2 days of focused execution.

📋 The P0 List (execute in this exact order)
Phase A — Quick Wins (~1 hour total, build momentum)
A1. Reconcile typography docs to code (~15 min)

Open CLAUDE.md line 36. Change "Inter (all weights, 700+ for headings) via google_fonts" → "Oswald (headings, display, buttons) + Open Sans (body, captions) via google_fonts. Reference: lib/app/theme/app_theme.dart."
Open design-system/jobdun/MASTER.md line 249 pre-delivery checklist. Change "Barlow / Barlow Condensed" → "Oswald / Open Sans".
Add a new "Sources of Truth" section at the top of MASTER.md:

  ## Sources of Truth
  When docs disagree with code, **code wins**. Tokens live in `lib/app/theme/tokens/`. This file describes intent; the tokens enforce it.

Show me the diffs.

A2. Delete dead code (~30 min)

In lib/app/theme/app_colors.dart:

Delete AppColors.white (line ~199)
Delete the entire AppColors static fallback class (lines ~198–223)
Delete the entire AppDarkColors class (lines ~225–234)


In lib/app/theme/app_theme.dart:

Delete AppTheme.brandDisplay() method (confirm zero callers first with grep)


Run flutter analyze and show me the output. Zero errors expected. If anything breaks, fix the import and re-verify.

A3. Gate debug-only routes (~5 min)

In lib/features/auth/presentation/pages/login_page.dart line ~274 ("Compare Logo Concepts" button):

dart  if (kDebugMode) ...[
    Gap(AppSpacing.md.h),
    AppButton(
      label: 'Compare Logo Concepts',
      variant: AppButtonVariant.text,
      onPressed: () => context.go('/dev/logo-compare'),
    ),
  ],

Audit for any other /dev/* or internal-only routes reachable from production screens. Gate them all.

A4. Vocabulary fix on login (~10 min)

In login_page.dart:

Line ~234: change 'Log in' / 'Logging in...' to 'LOG IN' / 'LOGGING IN...'
Line ~265: change 'Sign Up' to 'CREATE ACCOUNT'


Verify with grep -rn "Sign Up\|Sign up" lib/features/ — list every remaining violation for me to triage.


Phase B — Accessibility Killers (~3 hours total)
B1. Fix WCAG AA CTA contrast (~30 min)
The white-on-orange button label is 2.9:1 — fails WCAG AA (4.5:1 required) and fails App Store accessibility review.

In lib/core/widgets/app_button.dart, change the primary variant's foregroundColor from Colors.white to a new token: c.actionTx (or define JColors.actionTx = Color(0xFF1A0A03) if not already present — dark warm brown, 12.4:1 contrast on safety orange).
Verify: dark brown on #F97316 reads as bold and intentional (think road-sign signage, hi-vis vests). It does NOT look like a "broken" button.
Also fix the AppButton.text variant if it inherits the issue.
Show me the before/after diff.

B2. Touch target minimums (~30 min)
Raise all interactive surfaces to 44dp minimum (iOS HIG) / 48dp (Material).

lib/core/design/widgets/gv_chip.dart: change height from 30.h to 44.h. Verify the layout in jobs_page.dart doesn't break — chip row may need to wrap differently. Adjust internal padding so the visual chip still looks compact (use vertical padding to "shrink" the visible chip while keeping the tap target large).
lib/core/design/widgets/job_card.dart: APPLY NOW pill — raise to 44.h minimum.
jobs_page.dart POST JOB pill (line ~119): raise to 44.h.
Search-bar clear icon (jobs_page.dart ~line 188): wrap in SizedBox(width: 44, height: 44, child: ...) or use IconButton which gets it for free.

B3. Semantics labels on every GestureDetector button (~2 hours)
Zero Semantics widgets currently exist in the app. Screen reader users hear "button, button, button" on every interactive element.
For each of these 8 sites, wrap the GestureDetector (or replace with InkWell where appropriate) and add a Semantics wrapper with button: true and a descriptive label:
FileLineElementLabeljobs_page.dart~119POST JOB button'Post a new job'jobs_page.dart~188Search clear icon'Clear search'jobs_page.dart~257Error retry text'Retry loading jobs'job_card.dart~89APPLY NOW pill'Apply to {jobTitle}' (interpolate the title)gv_chip.dart~24Filter chip'{label} filter, {selected ? "selected" : "not selected"}'login_page.dart~170Remember me rowReplace with CheckboxListTile — collapses the double-tap-target issue and gets semantics for freelogin_page.dart~201FORGOT PASSWORD link'Forgot password? Tap to reset'login_page.dart~274Compare Logo Concepts'Developer tool: compare logo concepts' (also gated by kDebugMode from A3)
For each, show me the diff. Use this pattern:
dartSemantics(
  button: true,
  label: 'Apply to ${job.title}',
  child: GestureDetector(/* existing code */),
)

Phase C — Core Primitive: JTextField (~1 day, the highest-leverage P0 item)
This is the single most important fix. Build it right; you only do this once.
C1. Build lib/core/widgets/inputs/j_text_field.dart
Specs:

Wraps FormBuilderTextField from flutter_form_builder
Required params: name (form field key), label (string, sentence case in source — rendering decision is the widget's)
Optional params: hint, prefixIcon (Iconsax), suffixIcon, validator (use FormBuilderValidators.compose), obscureText, keyboardType, textInputAction, onSubmitted, enabled, helperText, initialValue, controller, inputFormatters, maxLength, autofillHints
Structure (vertical):

Label above field (using JTypography.labelMedium, color c.text2, NOT all-caps — sentence case)
Field itself (uses theme's InputDecorationTheme — don't duplicate)
Helper text OR error message below (mutually exclusive, animated swap)


States to handle:

Idle (default border c.border)
Focused (border c.action, 2px)
Error (border c.urgent, error text below in c.urgentTx)
Disabled (background c.surface.withValues(alpha: 0.5), label color c.textDisabled)


Accessibility:

semanticsLabel set to label string
enableInteractiveSelection: true
Touch target ≥ 56dp (theme default)


Behavior:

Validates on AutovalidateMode.onUserInteraction (validate after first blur, then on every keystroke — best UX)
Password fields: built-in show/hide toggle as the default suffixIcon when obscureText: true is passed
Reserve space for error text below so layout doesn't shift when error appears (SizedBox(height: 20) minimum below the field)



C2. Migrate 5 existing forms to JTextField
In order:

login_page.dart — email + password fields (the simplest, validates the migration pattern)
register_page.dart
forgot_password_page.dart
phone_auth_page.dart
profile_edit_page.dart (if exists)
job_create_page.dart (if exists)

For each migration:

Delete the inline _FieldLabel widget at the bottom of the file
Delete the inline FormBuilderTextField decoration boilerplate
Replace with JTextField(...) calls
Run flutter analyze after each file
Show me the diff for at least the first (login_page) so I can verify the pattern

C3. Delete the old lib/core/widgets/app_text_field.dart stub.
It's 43 lines, never imported, and will confuse future agents.

Phase D — Production Safety Net (~3 hours)
D1. Add Sentry crash reporting (~3 hours)

Add sentry_flutter: ^8.x (latest stable) to pubspec.yaml
Create lib/app/observability/sentry_setup.dart:

dart  Future<void> initSentry({required Future<void> Function() runApp}) async {
    await SentryFlutter.init(
      (options) {
        options.dsn = const String.fromEnvironment('SENTRY_DSN');
        options.environment = const String.fromEnvironment('FLUTTER_ENV', defaultValue: 'dev');
        options.tracesSampleRate = 0.2; // 20% sampling at 25k users
        options.profilesSampleRate = 0.1;
        options.attachScreenshot = false; // PII risk
        options.attachViewHierarchy = true;
        options.sendDefaultPii = false; // Privacy Act 1988
        options.beforeSend = (event, hint) {
          // Strip user emails/phones from error messages
          return _scrubPii(event);
        };
      },
      appRunner: runApp,
    );
  }

Update lib/main.dart to wrap runApp() inside initSentry
Add the DSN via --dart-define so it never lands in git: flutter run --dart-define=SENTRY_DSN=https://...
Update CLAUDE.md and README.md to document the dart-define requirement
Add a .env.example showing the required keys (no real values)
Test: throw a deliberate exception in main.dart (guarded by kDebugMode), confirm it lands in Sentry dashboard, then remove

D2. Build lib/core/formatters/j_formatters.dart (~2 hours, can run parallel)
Exactly as specified in the audit's Quick-Copy section. Then:

Audit job_card.dart, any profile/job-detail page, any message timestamp for hardcoded date/currency/phone formatting
Replace with JFormatters.currency(...), JFormatters.date(...), JFormatters.phone(...)


Phase E — Brand Decision Lock-In (~30 min, blocking on Ken)
E1. Logo decision
This requires me (Ken). Don't proceed without my answer.
Per design-system/jobdun/logo-brainstorm.md and memory, I lean modular brick-J direction. Confirm with me before executing:

"I'm about to delete the hammer-j-above, hammer-j-fused, hammer-j-side, hammer-j-head directories from pubspec.yaml assets and commit lib/core/assets/logo-jobdun-mark.svg + logo-jobdun-wordmark.svg as the production brick-J. Confirm?"

Once I confirm:

Remove the 4 rejected concept directories from pubspec.yaml assets list
Commit chosen SVGs at the production paths
Migrate login_page.dart (raw Image.asset('lib/core/assets/logo.png') + Text('JOBDUN')) to use JobdunLogo.full() or JobdunLogo.mark()
Migrate jobs_page.dart ShaderMask wordmark to either remove it (it's a screen title, not a brand mark — should just be Text('Find Work') with normal heading style) OR explicitly use JobdunLogo.wordmark() if branding the header is the design intent


📤 Output Protocol
For each phase:

Announce the phase. "Starting Phase A: Quick Wins."
Show me the diff for every file change. Use proper unified diff format or before / after code blocks.
Run flutter analyze mentally — predict any errors, fix them in the same response.
Mark the phase complete with a checklist:

   ✅ Phase A complete
   - [x] A1: Typography docs reconciled
   - [x] A2: Dead code deleted, flutter analyze clean
   - [x] A3: Debug routes gated
   - [x] A4: Login vocabulary fixed

Pause at phase boundaries so I can review and commit before the next phase. Don't dump all 4 phases in one message — it's unreviewable.
At the very end, give me a single commit message per phase (conventional commits format):

   feat(design-system): reconcile typography docs to code
   refactor(theme): delete AppColors/AppDarkColors dead code
   fix(a11y): WCAG AA CTA contrast + 44dp touch targets + semantics
   feat(widgets): build JTextField, migrate 5 forms
   feat(observability): add Sentry with PII scrubbing
   feat(formatters): add JFormatters for AUD currency/date/phone

🚫 Hard Constraints

No new dependencies without explicit approval. Sentry is pre-approved per D1; everything else needs justification.
No bypassing the grep gates. If scripts/validate.sh blocks something, fix the underlying issue, don't bypass.
No "I'll get to it later." Every P0 item ships this sprint.
No untested code. For JTextField, write at least one widget test (test/widgets/j_text_field_test.dart) verifying label renders, validator triggers, error state shows, password toggle works.
No silent breakage. After every file edit, predict whether flutter analyze will fail. If yes, fix in the same response.
No PII in Sentry. Scrub emails, phone numbers, and Supabase auth tokens before send.
No breaking the Gap() discipline. All vertical/horizontal spacing inside JTextField uses Gap(AppSpacing.x.h).
No raw Color(0xFF...) anywhere. Always go through JColors via context.c.x.


🧠 Reasoning You Must Show
For every non-trivial decision, give me:

Recommendation — what you're doing
Why this stage of Jobdun — why now, why this way, not the "perfect" way
Failure mode at 25k users — what breaks if we don't do this
Layman's analogy — plain-English explanation I can tell a non-technical co-founder

If you propose a different approach than the audit specified, justify it with concrete trade-offs at 25k users — not aesthetics.

📊 Definition of Done
The sprint is complete when:

 flutter analyze clean on the full repo
 dart format --set-exit-if-changed . passes
 scripts/validate.sh passes (grep gates green)
 flutter test passes including the new JTextField widget test
 All 5 forms render and submit correctly on iOS + Android (manual smoke test)
 Login screen reads as "LOG IN" / "CREATE ACCOUNT" in source, rendered uppercase
 Debug-only routes are not reachable in release builds
 Sentry receives a test event from --dart-define=FLUTTER_ENV=dev
 All 8 listed GestureDetector buttons have Semantics wrappers
 No element below 44dp tap target in any of the 21 existing screens
 WCAG AA verified: CTA button label contrast ≥ 4.5:1
 Logo decision committed; 4 rejected concept dirs removed from pubspec.yaml
 Audit doc updated with ## P0 Complete — 2026-05-XX section at the bottom, marking which items shipped


🚀 How We Start
Begin by asking me one clarifying question only if absolutely necessary (e.g., "Confirm brick-J as production logo?" before Phase E). Otherwise, start with Phase A immediately — those are zero-risk wins that build momentum.
Don't dump all 4 phases in one response. Ship Phase A, pause, let me commit, then Phase B, and so on.
Ready when you are. Start with: "Phase A: Quick Wins — starting now."