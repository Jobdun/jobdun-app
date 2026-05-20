import 'package:flutter/material.dart';

// AppSpacing, AppRadius, and AppMotion live in their own files so the
// design-system lint can target token files independently of the colour
// extension. Re-exported here so files that imported app_colors.dart for
// the legacy combined surface continue to compile transparently.
//
// New code should import via `core/design/colors.dart` (the barrel).
export 'app_spacing.dart';
export 'app_radii.dart';
export 'app_motion.dart';

// ─── Theme Extension ──────────────────────────────────────────────────────────
// Use `context.c.xxx` in all widgets. ThemeExtension lerps smoothly on
// animated theme switches.

class JColors extends ThemeExtension<JColors> {
  const JColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.surfaceRaised,
    required this.border,
    required this.text1,
    required this.text2,
    required this.text3,
    required this.action,
    required this.actionPressed,
    required this.actionBg,
    required this.actionTx,
    required this.onAction,
    required this.verified,
    required this.verifiedBg,
    required this.verifiedTx,
    required this.urgent,
    required this.urgentBg,
    required this.urgentTx,
    required this.available,
    required this.availableBg,
    required this.availableTx,
    required this.star,
  });

  /// App background — dark slate (#0F172A). MASTER §38.
  /// MUST be used as the Scaffold background on every screen.
  /// MUST NOT be replaced by white or light gray (#F8FAFC) anywhere.
  final Color background;

  /// Standard surface — cards, bottom sheets, input fills. MASTER §39.
  /// MUST be used as the default elevated chrome on top of c.background.
  /// MUST NOT be used as a screen background — that's c.background.
  final Color surface;

  /// Alias of c.surface for CardTheme wiring. Same value, different role.
  final Color card;

  /// Raised surface — selected states, elevated cards, secondary buttons. MASTER §40.
  /// MUST be used when a surface needs to read as "above" c.surface.
  final Color surfaceRaised;

  /// Input borders, dividers, hairlines. Same value as surfaceRaised by design. MASTER §45.
  /// MUST be used at 1.0 width for borders and dividers.
  final Color border;

  /// Primary text on dark backgrounds. MASTER §43.
  /// MUST be used for headlines, body copy, primary labels.
  final Color text1;

  /// Secondary text — labels, hints, metadata. MASTER §44.
  /// MUST be used for non-primary content (timestamps, helper text, decorative initials).
  /// Replaces decorative c.action per MASTER §51.
  final Color text2;

  /// Tertiary text — eyebrow labels, muted captions, placeholders, "tappable-but-not-primary" inline links (underlined).
  /// MUST be used for FieldLabel content and the muted-link pattern (see login_page.dart Forgot? link).
  final Color text3;

  /// Safety orange CTA accent. MASTER §51 reserved color.
  /// MUST be used for primary actions, loading indicators, URGENT badges, role chips.
  /// MUST NOT be used decoratively (avatar initials, location pins, timestamps) — use c.text2/c.text3 instead.
  final Color action;

  /// Pressed-state orange for c.action surfaces. ~12% darker than c.action.
  /// MUST be used only for pressed/highlight overlays on c.action elements.
  final Color actionPressed;

  /// Tinted orange background for orange-on-orange compositions (toast banners, pending badges).
  /// MUST be paired with c.actionTx text.
  /// MUST NOT be used as a standalone fill on top of c.background.
  final Color actionBg;

  /// Tinted orange text for c.actionBg backgrounds. Internal pair helper.
  final Color actionTx;

  /// Foreground when bg is c.action. White (#FFFFFF) per MASTER §1.
  /// MUST be used as the text/icon color on primary CTAs.
  /// MUST NOT be used as a standalone text color elsewhere — use c.text1 instead.
  final Color onAction;

  /// Verified/success green. MASTER §47.
  /// MUST be used only for confirmations and verification checkmarks.
  /// MUST NOT be used decoratively.
  final Color verified;

  /// Tinted green background for verified-status pairs. Internal pair helper.
  final Color verifiedBg;

  /// Tinted green text for c.verifiedBg backgrounds. Internal pair helper.
  final Color verifiedTx;

  /// Error/destructive red. MASTER §46.
  /// MUST be used only for errors and destructive confirmations.
  /// MUST NOT be used decoratively.
  final Color urgent;

  /// Tinted red background for error/urgent pairs. Internal pair helper.
  final Color urgentBg;

  /// Tinted red text for c.urgentBg backgrounds. Internal pair helper.
  final Color urgentTx;

  /// Availability blue — informational/status only. NEVER a tappable action color.
  /// MUST be used for "Available now" status indicators.
  /// MUST NOT be used as a link/CTA color — use c.action for CTAs, or the muted-link pattern (underlined c.text3) for inline links.
  final Color available;

  /// Tinted blue background for availability pairs. Internal pair helper.
  final Color availableBg;

  /// Tinted blue text for c.availableBg backgrounds. Internal pair helper.
  final Color availableTx;

  /// Star/rating amber. Decorative within rating widgets only.
  final Color star;

  static JColors of(BuildContext context) =>
      Theme.of(context).extension<JColors>()!;

  // ── Dark ──────────────────────────────────────────────────────────────────
  static const dark = JColors(
    background: Color(0xFF0F172A),
    surface: Color(0xFF1E293B),
    card: Color(0xFF1E293B),
    surfaceRaised: Color(0xFF334155),
    border: Color(0xFF334155),
    text1: Color(0xFFF1F5F9),
    text2: Color(0xFF94A3B8),
    text3: Color(0xFF64748B),
    action: Color(0xFFF97316),
    actionPressed: Color(0xFFEA6C0A),
    actionBg: Color(0xFF431407),
    actionTx: Color(0xFFFED7AA),
    onAction: Color(0xFFFFFFFF),
    verified: Color(0xFF22C55E),
    verifiedBg: Color(0xFF052E16),
    verifiedTx: Color(0xFF86EFAC),
    urgent: Color(0xFFEF4444),
    urgentBg: Color(0xFF450A0A),
    urgentTx: Color(0xFFFCA5A5),
    available: Color(0xFF3B82F6),
    availableBg: Color(0xFF1E3A5F),
    availableTx: Color(0xFF93C5FD),
    star: Color(0xFFF59E0B),
  );

  // ── Light (gated — app is dark-only; access via AppTheme._light() only) ───
  static const light = JColors(
    background: Color(0xFFF8FAFC),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    border: Color(0xFFCBD5E1),
    text1: Color(0xFF0F172A),
    text2: Color(0xFF475569),
    text3: Color(0xFF94A3B8),
    action: Color(0xFFF97316),
    actionPressed: Color(0xFFEA6C0A),
    actionBg: Color(0xFFFFEDD5),
    actionTx: Color(0xFF9A3412),
    onAction: Color(0xFFFFFFFF),
    verified: Color(0xFF16A34A),
    verifiedBg: Color(0xFFDCFCE7),
    verifiedTx: Color(0xFF166534),
    urgent: Color(0xFFDC2626),
    urgentBg: Color(0xFFFEE2E2),
    urgentTx: Color(0xFF991B1B),
    available: Color(0xFF2563EB),
    availableBg: Color(0xFFDBEAFE),
    availableTx: Color(0xFF1D4ED8),
    star: Color(0xFFF59E0B),
  );

  @override
  JColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? surfaceRaised,
    Color? border,
    Color? text1,
    Color? text2,
    Color? text3,
    Color? action,
    Color? actionPressed,
    Color? actionBg,
    Color? actionTx,
    Color? onAction,
    Color? verified,
    Color? verifiedBg,
    Color? verifiedTx,
    Color? urgent,
    Color? urgentBg,
    Color? urgentTx,
    Color? available,
    Color? availableBg,
    Color? availableTx,
    Color? star,
  }) => JColors(
    background: background ?? this.background,
    surface: surface ?? this.surface,
    card: card ?? this.card,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border: border ?? this.border,
    text1: text1 ?? this.text1,
    text2: text2 ?? this.text2,
    text3: text3 ?? this.text3,
    action: action ?? this.action,
    actionPressed: actionPressed ?? this.actionPressed,
    actionBg: actionBg ?? this.actionBg,
    actionTx: actionTx ?? this.actionTx,
    onAction: onAction ?? this.onAction,
    verified: verified ?? this.verified,
    verifiedBg: verifiedBg ?? this.verifiedBg,
    verifiedTx: verifiedTx ?? this.verifiedTx,
    urgent: urgent ?? this.urgent,
    urgentBg: urgentBg ?? this.urgentBg,
    urgentTx: urgentTx ?? this.urgentTx,
    available: available ?? this.available,
    availableBg: availableBg ?? this.availableBg,
    availableTx: availableTx ?? this.availableTx,
    star: star ?? this.star,
  );

  @override
  JColors lerp(JColors? other, double t) {
    if (other == null) return this;
    return JColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      card: Color.lerp(card, other.card, t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border: Color.lerp(border, other.border, t)!,
      text1: Color.lerp(text1, other.text1, t)!,
      text2: Color.lerp(text2, other.text2, t)!,
      text3: Color.lerp(text3, other.text3, t)!,
      action: Color.lerp(action, other.action, t)!,
      actionPressed: Color.lerp(actionPressed, other.actionPressed, t)!,
      actionBg: Color.lerp(actionBg, other.actionBg, t)!,
      actionTx: Color.lerp(actionTx, other.actionTx, t)!,
      onAction: Color.lerp(onAction, other.onAction, t)!,
      verified: Color.lerp(verified, other.verified, t)!,
      verifiedBg: Color.lerp(verifiedBg, other.verifiedBg, t)!,
      verifiedTx: Color.lerp(verifiedTx, other.verifiedTx, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
      urgentBg: Color.lerp(urgentBg, other.urgentBg, t)!,
      urgentTx: Color.lerp(urgentTx, other.urgentTx, t)!,
      available: Color.lerp(available, other.available, t)!,
      availableBg: Color.lerp(availableBg, other.availableBg, t)!,
      availableTx: Color.lerp(availableTx, other.availableTx, t)!,
      star: Color.lerp(star, other.star, t)!,
    );
  }
}

/// Shorthand: `context.c.background`, `context.c.action`, etc.
extension JColorsX on BuildContext {
  JColors get c => JColors.of(this);
}
