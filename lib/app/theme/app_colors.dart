import 'package:flutter/material.dart';

// ─── Theme Extension ──────────────────────────────────────────────────────────
// Use `context.c.xxx` in all widgets instead of static AppColors.*
// ThemeExtension lerps smoothly on animated theme switches.

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
    required this.actionBg,
    required this.actionTx,
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

  final Color background;
  final Color surface;
  final Color card;
  final Color surfaceRaised;
  final Color border;
  final Color text1;
  final Color text2;
  final Color text3;
  final Color action;       // safety orange — CTA only
  final Color actionBg;
  final Color actionTx;
  final Color verified;
  final Color verifiedBg;
  final Color verifiedTx;
  final Color urgent;
  final Color urgentBg;
  final Color urgentTx;
  final Color available;
  final Color availableBg;
  final Color availableTx;
  final Color star;

  static JColors of(BuildContext context) =>
      Theme.of(context).extension<JColors>()!;

  // ── Dark ──────────────────────────────────────────────────────────────────
  static const dark = JColors(
    background:    Color(0xFF0F172A),
    surface:       Color(0xFF1E293B),
    card:          Color(0xFF1E293B),
    surfaceRaised: Color(0xFF334155),
    border:        Color(0xFF334155),
    text1:         Color(0xFFF1F5F9),
    text2:         Color(0xFF94A3B8),
    text3:         Color(0xFF64748B),
    action:        Color(0xFFF97316),
    actionBg:      Color(0xFF431407),
    actionTx:      Color(0xFFFED7AA),
    verified:      Color(0xFF22C55E),
    verifiedBg:    Color(0xFF052E16),
    verifiedTx:    Color(0xFF86EFAC),
    urgent:        Color(0xFFEF4444),
    urgentBg:      Color(0xFF450A0A),
    urgentTx:      Color(0xFFFCA5A5),
    available:     Color(0xFF3B82F6),
    availableBg:   Color(0xFF1E3A5F),
    availableTx:   Color(0xFF93C5FD),
    star:          Color(0xFFF59E0B),
  );

  // ── Light ─────────────────────────────────────────────────────────────────
  static const light = JColors(
    background:    Color(0xFFF8FAFC),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1F5F9),
    border:        Color(0xFFCBD5E1),
    text1:         Color(0xFF0F172A),
    text2:         Color(0xFF475569),
    text3:         Color(0xFF94A3B8),
    action:        Color(0xFFF97316),
    actionBg:      Color(0xFFFFEDD5),
    actionTx:      Color(0xFF9A3412),
    verified:      Color(0xFF16A34A),
    verifiedBg:    Color(0xFFDCFCE7),
    verifiedTx:    Color(0xFF166534),
    urgent:        Color(0xFFDC2626),
    urgentBg:      Color(0xFFFEE2E2),
    urgentTx:      Color(0xFF991B1B),
    available:     Color(0xFF2563EB),
    availableBg:   Color(0xFFDBEAFE),
    availableTx:   Color(0xFF1D4ED8),
    star:          Color(0xFFF59E0B),
  );

  @override
  JColors copyWith({
    Color? background, Color? surface, Color? card, Color? surfaceRaised,
    Color? border, Color? text1, Color? text2, Color? text3,
    Color? action, Color? actionBg, Color? actionTx,
    Color? verified, Color? verifiedBg, Color? verifiedTx,
    Color? urgent, Color? urgentBg, Color? urgentTx,
    Color? available, Color? availableBg, Color? availableTx,
    Color? star,
  }) => JColors(
    background:    background    ?? this.background,
    surface:       surface       ?? this.surface,
    card:          card          ?? this.card,
    surfaceRaised: surfaceRaised ?? this.surfaceRaised,
    border:        border        ?? this.border,
    text1:         text1         ?? this.text1,
    text2:         text2         ?? this.text2,
    text3:         text3         ?? this.text3,
    action:        action        ?? this.action,
    actionBg:      actionBg      ?? this.actionBg,
    actionTx:      actionTx      ?? this.actionTx,
    verified:      verified      ?? this.verified,
    verifiedBg:    verifiedBg    ?? this.verifiedBg,
    verifiedTx:    verifiedTx    ?? this.verifiedTx,
    urgent:        urgent        ?? this.urgent,
    urgentBg:      urgentBg      ?? this.urgentBg,
    urgentTx:      urgentTx      ?? this.urgentTx,
    available:     available     ?? this.available,
    availableBg:   availableBg   ?? this.availableBg,
    availableTx:   availableTx   ?? this.availableTx,
    star:          star          ?? this.star,
  );

  @override
  JColors lerp(JColors? other, double t) {
    if (other == null) return this;
    return JColors(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      surfaceRaised: Color.lerp(surfaceRaised, other.surfaceRaised, t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      text1:         Color.lerp(text1,         other.text1,         t)!,
      text2:         Color.lerp(text2,         other.text2,         t)!,
      text3:         Color.lerp(text3,         other.text3,         t)!,
      action:        Color.lerp(action,        other.action,        t)!,
      actionBg:      Color.lerp(actionBg,      other.actionBg,      t)!,
      actionTx:      Color.lerp(actionTx,      other.actionTx,      t)!,
      verified:      Color.lerp(verified,      other.verified,      t)!,
      verifiedBg:    Color.lerp(verifiedBg,    other.verifiedBg,    t)!,
      verifiedTx:    Color.lerp(verifiedTx,    other.verifiedTx,    t)!,
      urgent:        Color.lerp(urgent,        other.urgent,        t)!,
      urgentBg:      Color.lerp(urgentBg,      other.urgentBg,      t)!,
      urgentTx:      Color.lerp(urgentTx,      other.urgentTx,      t)!,
      available:     Color.lerp(available,     other.available,     t)!,
      availableBg:   Color.lerp(availableBg,   other.availableBg,   t)!,
      availableTx:   Color.lerp(availableTx,   other.availableTx,   t)!,
      star:          Color.lerp(star,          other.star,          t)!,
    );
  }
}

/// Shorthand: `context.c.background`, `context.c.action`, etc.
extension JColorsX on BuildContext {
  JColors get c => JColors.of(this);
}

// ─── Static fallbacks ─────────────────────────────────────────────────────────
// Dark values kept so any files not yet migrated to context.c still compile.

abstract final class AppColors {
  static const action        = Color(0xFFF97316);
  static const actionBg      = Color(0xFF431407);
  static const actionTx      = Color(0xFFFED7AA);
  static const verified      = Color(0xFF22C55E);
  static const verifiedBg    = Color(0xFF052E16);
  static const verifiedTx    = Color(0xFF86EFAC);
  static const urgent        = Color(0xFFEF4444);
  static const urgentBg      = Color(0xFF450A0A);
  static const urgentTx      = Color(0xFFFCA5A5);
  static const available     = Color(0xFF3B82F6);
  static const availableBg   = Color(0xFF1E3A5F);
  static const availableTx   = Color(0xFF93C5FD);
  static const background    = Color(0xFF0F172A);
  static const surface       = Color(0xFF1E293B);
  static const card          = Color(0xFF1E293B);
  static const surfaceRaised = Color(0xFF334155);
  static const border        = Color(0xFF334155);
  static const text1         = Color(0xFFF1F5F9);
  static const text2         = Color(0xFF94A3B8);
  static const text3         = Color(0xFF64748B);
  static const foundation    = surfaceRaised;
  static const star          = Color(0xFFF59E0B);
  static const white         = Color(0xFFFFFFFF);
}

abstract final class AppDarkColors {
  static const background = AppColors.background;
  static const surface    = AppColors.surface;
  static const card       = AppColors.card;
  static const border     = AppColors.border;
  static const text1      = AppColors.text1;
  static const text2      = AppColors.text2;
  static const text3      = AppColors.text3;
  static const btnPri     = AppColors.action;
}

abstract final class AppSpacing {
  static const xs  = 4.0;
  static const sm  = 8.0;
  static const md  = 12.0;
  static const lg  = 16.0;
  static const xl  = 20.0;
  static const xxl = 32.0;
}

abstract final class AppRadius {
  static const badge  = 4.0;
  static const chip   = 6.0;
  static const btn    = 6.0;
  static const card   = 8.0;
  static const input  = 6.0;
  static const avatar = 8.0;
}
