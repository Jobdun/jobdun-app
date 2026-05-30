// ─────────────────────────────────────────────────────────────────────────────
// Jobdun — color contrast guard (dark theme = the shipping theme).
//
// Asserts every meaningful foreground/background pair in JColors.dark clears its
// WCAG 2.2 bar. Runs in CI via `flutter test`. If someone nudges a hex and breaks
// AA, this fails loudly instead of shipping an unreadable control.
//
// Bars: normal text 4.5:1 · large text / UI components (borders, icons, dots) 3:1.
//
// Light theme is intentionally NOT guarded here: the app ships dark-only and the
// light JColors is gated debt (see DESIGN_SYSTEM_SUGGESTIONS S14). Its text pairs
// all pass, but the brand orange/amber can't clear 3:1 as standalone marks on a
// white surface — a structural light-mode limit, not a fixable token. Wire +
// verify light before adding it to this guard.
//
// Color API: Flutter 3.27+ exposes .r/.g/.b as 0.0–1.0 doubles (sRGB-encoded).
// We use those directly — no /255, no deprecated .red/.green/.blue.
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/app/theme/app_colors.dart';
import 'package:jobdun/app/theme/app_theme.dart';

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = max(la, lb), lo = min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

class _Pair {
  const _Pair(this.name, this.fg, this.bg, this.min);
  final String name;
  final Color fg, bg;
  final double min; // 4.5 = text · 3.0 = large text / UI component
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const c = JColors.dark;
  final surface = c.surface;
  final bg = c.background;
  final raised = c.surfaceRaised;

  final textPairs = <_Pair>[
    // Primary CTA — the most-tapped control. Dark-on-orange, not white-on-orange.
    _Pair('onAction / action', c.onAction, c.action, 4.5),
    _Pair('onAction / actionPressed', c.onAction, c.actionPressed, 4.5),

    // Body / label text on every legitimate surface.
    _Pair('text1 / surface', c.text1, surface, 4.5),
    _Pair('text2 / surface', c.text2, surface, 4.5),
    _Pair('text3 / surface', c.text3, surface, 4.5),
    _Pair('text1 / background', c.text1, bg, 4.5),
    _Pair('text2 / background', c.text2, bg, 4.5),
    _Pair('text3 / background', c.text3, bg, 4.5),

    // surfaceRaised carries text1 ONLY (MASTER rule). text2/text3 fall below
    // 4.5 on raised, so we assert the supported pairing and forbid the rest.
    _Pair('text1 / surfaceRaised', c.text1, raised, 4.5),

    // Status-chip text on its tinted background.
    _Pair('actionTx / actionBg', c.actionTx, c.actionBg, 4.5),
    _Pair('verifiedTx / verifiedBg', c.verifiedTx, c.verifiedBg, 4.5),
    _Pair('urgentTx / urgentBg', c.urgentTx, c.urgentBg, 4.5),
    _Pair('availableTx / availableBg', c.availableTx, c.availableBg, 4.5),
    _Pair('warningTx / warningBg', c.warningTx, c.warningBg, 4.5),
  ];

  final uiPairs = <_Pair>[
    // Interactive boundaries — inputs sit on both surface and background.
    _Pair('borderStrong / surface', c.borderStrong, surface, 3.0),
    _Pair('borderStrong / background', c.borderStrong, bg, 3.0),
    // Accent + status marks (icons, dots, fills) as large/UI elements.
    _Pair('action / background', c.action, bg, 3.0),
    _Pair('star / surface', c.star, surface, 3.0),
    _Pair('warning / surface', c.warning, surface, 3.0),
    _Pair('verified / surface', c.verified, surface, 3.0),
    _Pair('urgent / surface', c.urgent, surface, 3.0),
    _Pair('available / surface', c.available, surface, 3.0),
  ];

  group('WCAG 2.2 — text contrast (4.5:1)', () {
    for (final p in textPairs) {
      test(p.name, () {
        final r = _contrast(p.fg, p.bg);
        expect(
          r,
          greaterThanOrEqualTo(p.min),
          reason: '${p.name} = ${r.toStringAsFixed(2)}:1, needs ${p.min}:1',
        );
      });
    }
  });

  group('WCAG 2.2 — UI / large-element contrast (3:1)', () {
    for (final p in uiPairs) {
      test(p.name, () {
        final r = _contrast(p.fg, p.bg);
        expect(
          r,
          greaterThanOrEqualTo(p.min),
          reason: '${p.name} = ${r.toStringAsFixed(2)}:1, needs ${p.min}:1',
        );
      });
    }
  });

  // The pinned ColorScheme drives every STOCK Material widget (FilledButton,
  // TextField, SnackBar, AppBar, Chip, Switch...). Guard its on-pairs too, on
  // the dark scheme that ships. `surface` as a UI mark on light is the same
  // orange-on-white limit documented above, so only dark is asserted.
  group('WCAG 2.2 — ColorScheme on-pairs (stock M3 widgets, dark)', () {
    final s = AppTheme.colorScheme(Brightness.dark);
    final schemePairs = <_Pair>[
      _Pair('onPrimary / primary', s.onPrimary, s.primary, 4.5),
      _Pair(
        'onPrimaryContainer / primaryContainer',
        s.onPrimaryContainer,
        s.primaryContainer,
        4.5,
      ),
      _Pair('onSecondary / secondary', s.onSecondary, s.secondary, 4.5),
      _Pair('onTertiary / tertiary', s.onTertiary, s.tertiary, 4.5),
      _Pair('onError / error', s.onError, s.error, 4.5),
      _Pair(
        'onErrorContainer / errorContainer',
        s.onErrorContainer,
        s.errorContainer,
        4.5,
      ),
      _Pair('onSurface / surface', s.onSurface, s.surface, 4.5),
      _Pair('onSurfaceVariant / surface', s.onSurfaceVariant, s.surface, 4.5),
      _Pair('outline / surface', s.outline, s.surface, 3.0),
    ];
    for (final p in schemePairs) {
      test(p.name, () {
        final r = _contrast(p.fg, p.bg);
        expect(
          r,
          greaterThanOrEqualTo(p.min),
          reason: '${p.name} = ${r.toStringAsFixed(2)}:1, needs ${p.min}:1',
        );
      });
    }
  });

  // `border` (#334155) is a decorative same-tone divider, exempt from WCAG
  // 1.4.11 (which covers only controls/meaningful graphics). It MUST stay
  // subtle: interactive edges use `borderStrong`, not `border`. Lock that
  // intent so nobody "fixes" the divider into a hard line.
  test('border stays subtle (decorative divider, intentionally < 3:1)', () {
    expect(_contrast(c.border, surface), lessThan(3.0));
  });
}
