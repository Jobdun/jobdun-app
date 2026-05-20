import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/core/theme/app_icons.dart';

/// Compile-time + render-time guard for the AppIcons catalogue.
///
/// If any constant in `AppIcons` references a Phosphor name that doesn't
/// exist in the installed `phosphor_flutter` version, this file fails to
/// compile. If a constant compiles but throws on render (e.g. malformed
/// IconData), this test catches it at run-time.
///
/// Every entry that lands in the catalogue must also land in `_allIcons`
/// below. The intentional friction stops "ghost" constants from drifting
/// into `AppIcons` without anyone exercising them.
void main() {
  testWidgets('AppIcons — every constant renders without throwing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _allIcons
                  .map((data) => Icon(data, size: 24))
                  .toList(growable: false),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Icon), findsNWidgets(_allIcons.length));
  });
}

/// Every IconData constant exposed by [AppIcons]. Add to this list when
/// you add to the catalogue — the test then re-renders the new entry.
const List<IconData> _allIcons = [
  // Navigation pairs
  AppIcons.homeOutline, AppIcons.homeFilled,
  AppIcons.findJobsOutline, AppIcons.findJobsFilled,
  AppIcons.myJobsOutline, AppIcons.myJobsFilled,
  AppIcons.appliedOutline, AppIcons.appliedFilled,
  AppIcons.applicantsOutline, AppIcons.applicantsFilled,
  AppIcons.messagesOutline, AppIcons.messagesFilled,
  AppIcons.profileOutline, AppIcons.profileFilled,

  // Navigation singles
  AppIcons.back, AppIcons.arrowLeft, AppIcons.chevronRight,
  AppIcons.chevronDown, AppIcons.chevronUp,

  // Domain
  AppIcons.verified, AppIcons.successCircle, AppIcons.successCircleFilled,
  AppIcons.licence, AppIcons.trade, AppIcons.builder, AppIcons.building,
  AppIcons.location, AppIcons.locationFilled, AppIcons.locationUnavailable,
  AppIcons.budget, AppIcons.calendar, AppIcons.clock,
  AppIcons.urgent, AppIcons.warning, AppIcons.policy, AppIcons.shield,
  AppIcons.chat, AppIcons.chatFilled, AppIcons.messageText,
  AppIcons.user, AppIcons.userFilled, AppIcons.userEdit,
  AppIcons.star, AppIcons.starFilled,

  // Auth / form
  AppIcons.email, AppIcons.emailNotification, AppIcons.lock, AppIcons.phone,
  AppIcons.eyeOpen, AppIcons.eyeClosed,

  // Actions
  AppIcons.search, AppIcons.filter, AppIcons.sort,
  AppIcons.add, AppIcons.addCircle, AppIcons.addSquare,
  AppIcons.edit, AppIcons.send, AppIcons.info, AppIcons.check,
  AppIcons.close, AppIcons.closeBox, AppIcons.closeCircle, AppIcons.more,

  // Surfaces / decoration
  AppIcons.briefcase, AppIcons.briefcaseFilled,
  AppIcons.house, AppIcons.houseFilled,
  AppIcons.document, AppIcons.documentFilled,
  AppIcons.camera, AppIcons.card, AppIcons.wallet, AppIcons.receipt,
  AppIcons.quote, AppIcons.award,
  AppIcons.lightning, AppIcons.lightningFilled,
  AppIcons.imageEmpty, AppIcons.gridView,
  AppIcons.gps, AppIcons.gpsFilled, AppIcons.map,
  AppIcons.sun, AppIcons.moon,

  // Misc
  AppIcons.notification, AppIcons.mapLayer, AppIcons.wifi, AppIcons.hardHat,
];
