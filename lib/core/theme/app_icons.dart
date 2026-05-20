import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Semantic icon catalogue for Jobdun.
///
/// **The single point of contact with `phosphor_flutter`.** Every other
/// file in the app imports from this catalogue. Feature code never
/// references `PhosphorIconsBold.*` / `PhosphorIconsFill.*` directly.
///
/// Why: when we re-evaluate icon libraries (or commission a
/// construction-specific supplemental pack in Phase 2), one file changes
/// — not 200.
///
/// **Convention.**
/// - Bold weight = default / outline / inactive state.
/// - Fill weight = active / selected state and critical alerts.
///
/// **Nav pairs** are records with `outline` (Bold) + `filled` (Fill) members.
/// Pass `AppIcons.home.outline` / `.filled` into the nav widget.
///
/// **Singles** are bare `IconData` — pass straight into `Icon(...)` or any
/// primitive (e.g. `JButton(icon: AppIcons.search)`).
abstract final class AppIcons {
  // ─── Navigation pairs (outline + filled flats) ────────────────────────────
  // Active state cross-fades outline → filled via AppMotion.fast. See
  // _BottomNav in lib/features/home/presentation/pages/home_shell_page.dart.
  //
  // Pairs use flat constants (e.g. `homeOutline` + `homeFilled`) rather than
  // record wrappers because Dart 3 record field access isn't const-evaluable;
  // `TabSpec` constructors are `const`.

  static const IconData homeOutline = PhosphorIconsBold.house;
  static const IconData homeFilled = PhosphorIconsFill.house;

  static const IconData findJobsOutline = PhosphorIconsBold.briefcase;
  static const IconData findJobsFilled = PhosphorIconsFill.briefcase;

  static const IconData myJobsOutline = PhosphorIconsBold.hammer;
  static const IconData myJobsFilled = PhosphorIconsFill.hammer;

  static const IconData appliedOutline = PhosphorIconsBold.checkSquare;
  static const IconData appliedFilled = PhosphorIconsFill.checkSquare;

  static const IconData applicantsOutline = PhosphorIconsBold.users;
  static const IconData applicantsFilled = PhosphorIconsFill.users;

  static const IconData messagesOutline = PhosphorIconsBold.chatCircle;
  static const IconData messagesFilled = PhosphorIconsFill.chatCircle;

  static const IconData profileOutline = PhosphorIconsBold.user;
  static const IconData profileFilled = PhosphorIconsFill.user;

  // ─── Navigation (single, decorative — not the tab pair) ───────────────────

  /// Back affordance in app bars. Caret reads heavier than `arrowLeft`.
  static const IconData back = PhosphorIconsBold.caretLeft;

  /// Distinct from `back` — used where a literal "go back to previous screen"
  /// metaphor is preferred over a caret affordance.
  static const IconData arrowLeft = PhosphorIconsBold.arrowLeft;

  /// Row affordance — "tap to drill in".
  static const IconData chevronRight = PhosphorIconsBold.caretRight;

  /// Collapsible / dropdown caret.
  static const IconData chevronDown = PhosphorIconsBold.caretDown;

  // ─── Domain (Jobdun-specific concepts) ────────────────────────────────────

  /// Verified credential / sealed badge.
  static const IconData verified = PhosphorIconsBold.sealCheck;

  /// Generic success tick inside a circle. Use for snackbars and inline
  /// success affordances; for the "verified credential" badge use [verified].
  static const IconData successCircle = PhosphorIconsBold.checkCircle;

  /// Trade licence card.
  static const IconData licence = PhosphorIconsBold.identificationBadge;

  /// Trade tool. Used on trade-required chips and trade rows.
  static const IconData trade = PhosphorIconsBold.wrench;

  /// Builder organisation / company chrome.
  static const IconData builder = PhosphorIconsBold.buildings;

  /// Alias of [builder] when the surrounding semantic is "the physical
  /// building" rather than "the builder organisation". Same glyph.
  static const IconData building = PhosphorIconsBold.buildings;

  /// Map pin (outline). Used in headers and address rows.
  static const IconData location = PhosphorIconsBold.mapPin;

  /// Map pin (filled). Used on selected map markers and active location
  /// indicators.
  static const IconData locationFilled = PhosphorIconsFill.mapPin;

  /// Rate / budget / currency input.
  static const IconData budget = PhosphorIconsBold.currencyDollar;

  /// Calendar / date picker.
  static const IconData calendar = PhosphorIconsBold.calendar;

  /// Time / recency / "X minutes ago".
  static const IconData clock = PhosphorIconsBold.clock;

  /// Urgent / critical alert. **Fill weight intentionally** — outranks the
  /// generic Bold [warning] for active-alert semantics.
  static const IconData urgent = PhosphorIconsFill.warning;

  /// Soft warning / cautionary state. Bold weight.
  static const IconData warning = PhosphorIconsBold.warning;

  /// Policy / privacy / legal-shield chrome.
  static const IconData policy = PhosphorIconsBold.shieldCheck;

  /// Generic messaging (non-nav) — chat bubble.
  static const IconData chat = PhosphorIconsBold.chatCircle;

  /// Profile-style avatar mark (non-nav).
  static const IconData user = PhosphorIconsBold.user;

  /// Star rating.
  static const IconData star = PhosphorIconsBold.star;

  // ─── Auth / form prefixes ─────────────────────────────────────────────────

  /// Email field prefix.
  static const IconData email = PhosphorIconsBold.envelope;

  /// Password field prefix.
  static const IconData lock = PhosphorIconsBold.lock;

  /// Phone field prefix / dial action.
  static const IconData phone = PhosphorIconsBold.phone;

  /// Password reveal — paired with [eyeClosed]. Used internally by
  /// `JTextField`'s obscure-toggle.
  static const IconData eyeOpen = PhosphorIconsBold.eye;

  /// Password obscure — paired with [eyeOpen]. Used internally by
  /// `JTextField`'s obscure-toggle.
  static const IconData eyeClosed = PhosphorIconsBold.eyeSlash;

  // ─── Actions ──────────────────────────────────────────────────────────────

  /// Search input prefix.
  static const IconData search = PhosphorIconsBold.magnifyingGlass;

  /// Filter affordance.
  static const IconData filter = PhosphorIconsBold.funnel;

  /// Sort affordance.
  static const IconData sort = PhosphorIconsBold.sortAscending;

  /// Add / create. The thin-stroke `plus` reads as a primary CTA glyph.
  static const IconData add = PhosphorIconsBold.plus;

  /// Edit (pencil).
  static const IconData edit = PhosphorIconsBold.pencilSimple;

  /// Send (paper plane). Used on submit-job and submit-application chrome.
  static const IconData send = PhosphorIconsBold.paperPlaneRight;

  /// Inline help affordance.
  static const IconData info = PhosphorIconsBold.info;

  /// Standalone tick (not in a circle — see [successCircle] for that).
  static const IconData check = PhosphorIconsBold.check;

  /// Close / dismiss — bare X.
  static const IconData close = PhosphorIconsBold.x;

  /// Alias of [close] for callers that semantically mean "dismiss a sheet".
  /// Same glyph; the alias keeps the intent at the call site readable.
  static const IconData closeBox = PhosphorIconsBold.x;

  /// Close inside a circle — used on sheet dismiss controls.
  static const IconData closeCircle = PhosphorIconsBold.xCircle;

  /// Overflow / more menu.
  static const IconData more = PhosphorIconsBold.dotsThreeOutline;

  /// Archive — hide a row from the active list without deleting (used on
  /// the conversation swipe action; backed by per-side `archived_at` columns
  /// on `conversations`).
  static const IconData archive = PhosphorIconsBold.archive;

  /// Filled tick — confirmed/success states that need stronger visual weight
  /// than [successCircle].
  static const IconData successCircleFilled = PhosphorIconsFill.checkCircle;

  /// Plus inside a circle.
  static const IconData addCircle = PhosphorIconsBold.plusCircle;

  /// Plus inside a square. Phosphor uses square containers for "input-like"
  /// add affordances (e.g. add to list, add photo).
  static const IconData addSquare = PhosphorIconsBold.plusSquare;

  /// Caret up — collapsibles, scroll-to-top.
  static const IconData chevronUp = PhosphorIconsBold.caretUp;

  // ─── Surfaces / decorative singles ────────────────────────────────────────

  /// Decorative briefcase (non-nav).
  static const IconData briefcase = PhosphorIconsBold.briefcase;

  /// Filled briefcase (non-nav, e.g. selected job-type chips).
  static const IconData briefcaseFilled = PhosphorIconsFill.briefcase;

  /// Decorative home (non-nav).
  static const IconData house = PhosphorIconsBold.house;

  /// Filled home (non-nav).
  static const IconData houseFilled = PhosphorIconsFill.house;

  /// Decorative profile / avatar (non-nav).
  static const IconData userFilled = PhosphorIconsFill.user;

  /// Inbound chat bubble with text lines.
  static const IconData messageText = PhosphorIconsBold.chatCenteredText;

  /// Filled chat bubble (non-nav).
  static const IconData chatFilled = PhosphorIconsFill.chatCircle;

  /// Document with text (Bold). Used on cards, applications, profile rows.
  static const IconData document = PhosphorIconsBold.fileText;

  /// Document with text (Fill) — active / selected state.
  static const IconData documentFilled = PhosphorIconsFill.fileText;

  /// Camera capture.
  static const IconData camera = PhosphorIconsBold.camera;

  /// Credit / payment card.
  static const IconData card = PhosphorIconsBold.creditCard;

  /// Wallet / cash on hand. Distinct from [budget] (single-currency glyph).
  static const IconData wallet = PhosphorIconsBold.wallet;

  /// Receipt / invoice.
  static const IconData receipt = PhosphorIconsBold.receipt;

  /// Block-quote / testimonial quote mark.
  static const IconData quote = PhosphorIconsBold.quotes;

  /// Award / trophy.
  static const IconData award = PhosphorIconsBold.trophy;

  /// Generic shield (no checkmark). [policy] is the verified-shield variant.
  static const IconData shield = PhosphorIconsBold.shield;

  /// Email-with-notification badge. Phosphor has no badge variant — we
  /// reuse the base envelope; callers stack a dot overlay when they need
  /// the unread cue.
  static const IconData emailNotification = PhosphorIconsBold.envelope;

  /// Lightning / quick-action flash (Bold).
  static const IconData lightning = PhosphorIconsBold.lightning;

  /// Lightning filled — used for URGENT-style activation states.
  static const IconData lightningFilled = PhosphorIconsFill.lightning;

  /// Empty / broken image — portfolio empty state, gallery error.
  static const IconData imageEmpty = PhosphorIconsBold.imageBroken;

  /// Grid / squares layout toggle.
  static const IconData gridView = PhosphorIconsBold.squaresFour;

  /// GPS targeting reticle.
  static const IconData gps = PhosphorIconsBold.crosshair;

  /// GPS targeting reticle, filled / active.
  static const IconData gpsFilled = PhosphorIconsFill.crosshair;

  /// Folded map (not the pin — see [location]).
  static const IconData map = PhosphorIconsBold.mapTrifold;

  /// Location unavailable / unknown. Phosphor has no `mapPinSlash`; we use
  /// the outline-only [mapPinLine] which reads as "location pending".
  static const IconData locationUnavailable = PhosphorIconsBold.mapPinLine;

  /// Edit profile — user with adjustment glyph. Phosphor uses gear over
  /// pencil for this semantic.
  static const IconData userEdit = PhosphorIconsBold.userGear;

  /// Filled star — rating active state.
  static const IconData starFilled = PhosphorIconsFill.star;

  /// Light-mode toggle.
  static const IconData sun = PhosphorIconsBold.sun;

  /// Dark-mode toggle.
  static const IconData moon = PhosphorIconsBold.moon;

  // ─── Misc / utility ───────────────────────────────────────────────────────

  /// Header notification bell.
  static const IconData notification = PhosphorIconsBold.bell;

  /// Map style / layer toggle (e.g. list vs map view).
  static const IconData mapLayer = PhosphorIconsBold.stack;

  /// Connectivity / offline banner.
  static const IconData wifi = PhosphorIconsBold.wifiHigh;

  /// Safety / PPE. Reserved for future use.
  static const IconData hardHat = PhosphorIconsBold.hardHat;
}
