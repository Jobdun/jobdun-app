import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/auth/domain/entities/user_role.dart';
import 'package:jobdun/features/home/presentation/pages/home_shell_page.dart';

/// Verifies the role-aware tab roster surfaces icons + labels for every
/// tab, in both Builder and Trade roles. Catches regressions where slots 2/3
/// drift away from the spec, or labels get dropped from the nav.
///
/// These tests use `TabSpec.forRole` directly rather than mounting the
/// full `HomeShellPage` (which depends on Riverpod, GoRouter shell,
/// connectivity, and authProvider initialization). Testing the tab roster
/// in isolation gives us a fast, hermetic check on the contract.
void main() {
  group('TabSpec.forRole', () {
    // Floating-dock nav (2026-06-11): four work tabs; Profile moved off the bar
    // to the avatar/account-sheet — the dock's 5th slot is a button, not a tab.
    test('builder roster has 4 work tabs, slots 1/2 are My Jobs and Applicants', () {
      final tabs = TabSpec.forRole(UserRole.builder);
      expect(tabs, hasLength(4));
      expect(tabs[0].shortLabel, 'Home');
      expect(tabs[1].shortLabel, 'My Jobs');
      expect(tabs[1].semanticsLabel, 'My posted jobs');
      expect(tabs[2].shortLabel, 'Applicants');
      expect(tabs[2].semanticsLabel, 'Job applicants');
      expect(tabs[3].shortLabel, 'Messages');
    });

    test('trade roster has 4 work tabs, slots 1/2 are Find and Applied', () {
      final tabs = TabSpec.forRole(UserRole.trade);
      expect(tabs, hasLength(4));
      expect(tabs[0].shortLabel, 'Home');
      expect(tabs[1].shortLabel, 'Find');
      expect(tabs[1].semanticsLabel, 'Find jobs nearby');
      expect(tabs[2].shortLabel, 'Applied');
      expect(tabs[2].semanticsLabel, 'My job applications');
      expect(tabs[3].shortLabel, 'Messages');
    });

    test('null role defaults to the trade roster (pre-role-load state)', () {
      final tabs = TabSpec.forRole(null);
      expect(tabs[1].shortLabel, 'Find');
      expect(tabs[2].shortLabel, 'Applied');
    });

    test('every tab has distinct outline + filled icon constants', () {
      for (final role in <UserRole?>[UserRole.builder, UserRole.trade, null]) {
        final tabs = TabSpec.forRole(role);
        for (final tab in tabs) {
          expect(
            tab.outlineIcon,
            isNot(equals(tab.filledIcon)),
            reason:
                '${tab.shortLabel} (role: $role) — outline and filled must be distinct icons',
          );
        }
      }
    });

    test('short labels are ≤10 characters (fits iPhone-SE 5-tab width)', () {
      for (final role in <UserRole?>[UserRole.builder, UserRole.trade]) {
        for (final tab in TabSpec.forRole(role)) {
          expect(
            tab.shortLabel.length,
            lessThanOrEqualTo(10),
            reason: 'Label "${tab.shortLabel}" too long for compact nav width',
          );
        }
      }
    });
  });
}
