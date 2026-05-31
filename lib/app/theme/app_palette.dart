part of 'app_colors.dart';

/// TIER 1 — primitives. The Tailwind v3 families used by either theme, plus 4
/// custom steps. Private to the `app_colors.dart` library: widgets must go
/// through [JColors]; nothing outside this library can reach `_Palette`.
class _Palette {
  _Palette._();

  // ── Slate (neutral) — the entire UI is built from this ramp ───────────────
  static const slate50 = Color(0xFFF8FAFC); // light background
  static const slate100 = Color(0xFFF1F5F9); // dark text1 / light raised
  static const slate300 = Color(0xFFCBD5E1); // light border
  static const slate400 = Color(0xFF94A3B8); // dark text2
  static const slate450 = Color(
    0xFF8B98AB,
  ); // CUSTOM — gap-fill, dark text3 (5.0:1)
  static const slate500 = Color(0xFF64748B); // light text3
  static const slate550 = Color(
    0xFF708096,
  ); // CUSTOM — gap-fill, borderStrong (3.63:1)
  static const slate600 = Color(0xFF475569); // light text2
  static const slate700 = Color(0xFF334155); // dark raised + dark border
  static const slate800 = Color(0xFF1E293B); // dark surface / card
  static const slate900 = Color(
    0xFF0F172A,
  ); // dark background / onAction / light text1
  static const white = Color(0xFFFFFFFF); // light surface / card

  // ── Orange (brand accent) — the ONE brand colour ─────────────────────────
  static const orange100 = Color(0xFFFFEDD5); // light actionBg
  static const orange200 = Color(0xFFFED7AA); // dark actionTx
  static const orange500 = Color(0xFFF97316); // action (both)
  static const orange550 = Color(
    0xFFEA6C0A,
  ); // CUSTOM — hand-tuned pressed (~12% darker)
  static const orange700 = Color(
    0xFFC2410C,
  ); // light actionInk — orange text/icon on white (~4.95:1)
  static const orange800 = Color(0xFF9A3412); // light actionTx
  static const orange950 = Color(0xFF431407); // dark actionBg

  // ── Green (success) ───────────────────────────────────────────────────────
  static const green100 = Color(0xFFDCFCE7); // light verifiedBg
  static const green300 = Color(0xFF86EFAC); // dark verifiedTx
  static const green500 = Color(0xFF22C55E); // dark verified
  static const green600 = Color(0xFF16A34A); // light verified
  static const green800 = Color(0xFF166534); // light verifiedTx
  static const green950 = Color(0xFF052E16); // dark verifiedBg

  // ── Red (danger) ──────────────────────────────────────────────────────────
  static const red100 = Color(0xFFFEE2E2); // light urgentBg
  static const red300 = Color(0xFFFCA5A5); // dark urgentTx
  static const red500 = Color(0xFFEF4444); // dark urgent
  static const red600 = Color(0xFFDC2626); // light urgent
  static const red800 = Color(0xFF991B1B); // light urgentTx
  static const red950 = Color(0xFF450A0A); // dark urgentBg

  // ── Blue (information — status only) ──────────────────────────────────────
  static const blue100 = Color(0xFFDBEAFE); // light availableBg
  static const blue300 = Color(0xFF93C5FD); // dark availableTx
  static const blue500 = Color(0xFF3B82F6); // dark available
  static const blue600 = Color(0xFF2563EB); // light available
  static const blue700 = Color(0xFF1D4ED8); // light availableTx
  static const navy900 = Color(
    0xFF1E3A5F,
  ); // CUSTOM — desaturated info surface (dark availableBg)

  // ── Amber (warning + rating star) ─────────────────────────────────────────
  static const amber100 = Color(0xFFFEF3C7); // light warningBg
  static const amber300 = Color(0xFFFCD34D); // dark warningTx
  static const amber500 = Color(0xFFF59E0B); // star (both) + dark warning
  static const amber600 = Color(
    0xFFD97706,
  ); // light warning + light star (3:1 on white)
  static const amber800 = Color(0xFF92400E); // light warningTx
  static const amber950 = Color(0xFF451A03); // dark warningBg
}
