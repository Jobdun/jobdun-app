// ─────────────────────────────────────────────────────────────────────────────
// Jobdun — color contrast guard. Runs in CI via `flutter test`.
//
// Asserts every meaningful foreground/background pair clears its WCAG 2.2 bar,
// for BOTH themes, so a future hex tweak can't silently ship an unreadable
// control. Three layers are guarded:
//   1. JColors token pairs (what widgets use via context.c).
//   2. The pinned ColorScheme on-pairs (what stock Material widgets use).
//   3. A coverage meta-test: every JColors token must appear in a pair or be
//      explicitly exempt — so a NEW token can't ship unguarded.
//
// Bars: normal text 4.5:1 · large text / UI components (borders, icons, dots) 3:1.
//
// `action`/`primary` as a standalone UI mark on `surface` is NOT asserted: the
// brand orange is 2.80:1 on white by design (filled buttons are label-carried).
// So that one pair is dark-only.
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

// Token pairs by NAME (resolved per theme via JColors.toMap()).
const _textPairs = <(String, String)>[
  ('onAction', 'action'),
  ('onAction', 'actionPressed'),
  ('text1', 'surface'),
  ('text2', 'surface'),
  ('text3', 'surface'),
  ('text1', 'background'),
  ('text2', 'background'),
  ('text3', 'background'),
  // surfaceRaised carries text1 ONLY (MASTER rule) — text2/text3 fall below
  // 4.5 on raised, so the only raised text pairing we assert is text1.
  ('text1', 'surfaceRaised'),
  ('actionTx', 'actionBg'),
  ('verifiedTx', 'verifiedBg'),
  ('urgentTx', 'urgentBg'),
  ('availableTx', 'availableBg'),
  ('warningTx', 'warningBg'),
];

const _uiPairs = <(String, String)>[
  ('borderStrong', 'surface'),
  ('borderStrong', 'background'),
  ('star', 'surface'),
  ('warning', 'surface'),
  ('verified', 'surface'),
  ('urgent', 'surface'),
  ('available', 'surface'),
];

// Orange as a standalone UI mark on the dark canvas — passes on slate (6.37),
// fails on white (2.80) by design, so dark-only.
const _darkOnlyUiPairs = <(String, String)>[('action', 'background')];

void main() {
  final themes = <({String name, JColors c, bool isDark})>[
    (name: 'dark', c: JColors.dark, isDark: true),
    (name: 'light', c: JColors.light, isDark: false),
  ];

  for (final t in themes) {
    final m = t.c.toMap();
    Color col(String n) => m[n]!;

    group('WCAG text 4.5:1 (${t.name})', () {
      for (final (fg, bg) in _textPairs) {
        test('$fg / $bg', () {
          final r = _contrast(col(fg), col(bg));
          expect(
            r,
            greaterThanOrEqualTo(4.5),
            reason: '${t.name} · $fg/$bg = ${r.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    group('WCAG UI/large 3:1 (${t.name})', () {
      final pairs = [..._uiPairs, if (t.isDark) ..._darkOnlyUiPairs];
      for (final (fg, bg) in pairs) {
        test('$fg / $bg', () {
          final r = _contrast(col(fg), col(bg));
          expect(
            r,
            greaterThanOrEqualTo(3.0),
            reason: '${t.name} · $fg/$bg = ${r.toStringAsFixed(2)}:1',
          );
        });
      }
    });

    // `border` is a decorative same-tone divider, exempt from WCAG 1.4.11. It
    // MUST stay subtle — interactive edges use `borderStrong`, not `border`.
    test('border stays subtle, intentionally < 3:1 (${t.name})', () {
      expect(_contrast(col('border'), col('surface')), lessThan(3.0));
    });
  }

  // The pinned ColorScheme drives every STOCK Material widget. Guard its
  // on-pairs on the dark scheme that ships.
  group('WCAG ColorScheme on-pairs (stock M3 widgets, dark)', () {
    final s = AppTheme.colorScheme(Brightness.dark);
    final pairs = <(String, Color, Color, double)>[
      ('onPrimary / primary', s.onPrimary, s.primary, 4.5),
      (
        'onPrimaryContainer / primaryContainer',
        s.onPrimaryContainer,
        s.primaryContainer,
        4.5,
      ),
      ('onSecondary / secondary', s.onSecondary, s.secondary, 4.5),
      ('onTertiary / tertiary', s.onTertiary, s.tertiary, 4.5),
      ('onError / error', s.onError, s.error, 4.5),
      (
        'onErrorContainer / errorContainer',
        s.onErrorContainer,
        s.errorContainer,
        4.5,
      ),
      ('onSurface / surface', s.onSurface, s.surface, 4.5),
      ('onSurfaceVariant / surface', s.onSurfaceVariant, s.surface, 4.5),
      (
        'onInverseSurface / inverseSurface',
        s.onInverseSurface,
        s.inverseSurface,
        4.5,
      ),
      ('outline / surface', s.outline, s.surface, 3.0),
    ];
    for (final (label, fg, bg, min) in pairs) {
      test(label, () {
        final r = _contrast(fg, bg);
        expect(
          r,
          greaterThanOrEqualTo(min),
          reason: '$label = ${r.toStringAsFixed(2)}:1, needs $min:1',
        );
      });
    }
  });

  // Coverage: every JColors token must be guarded above or explicitly exempt,
  // so a newly-added token can't slip through unverified.
  test('every JColors token is covered by a contrast pair (none unguarded)', () {
    final guarded = <String>{
      for (final (a, b) in [
        ..._textPairs,
        ..._uiPairs,
        ..._darkOnlyUiPairs,
      ]) ...[a, b],
      'border', // asserted by the "border stays subtle" test
    };
    // Exempt: `card` is an alias of `surface` (same value, no separate pair).
    const exempt = <String>{'card'};

    final all = JColors.dark.toMap().keys.toSet();
    expect(
      all.difference(guarded).difference(exempt),
      isEmpty,
      reason: 'Unguarded token(s) — add a contrast pair or mark exempt.',
    );
    // Reverse checks: guard/exempt must reference real tokens (catch renames).
    expect(
      guarded.difference(all),
      isEmpty,
      reason: 'Guard references unknown token(s).',
    );
    expect(
      exempt.difference(all),
      isEmpty,
      reason: 'Exempt references unknown token(s).',
    );
  });
}
