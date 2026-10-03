import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/auth/presentation/providers/auth_provider.dart';
import 'package:jobdun/features/auth/presentation/pages/phone_auth_page.dart';
import 'package:jobdun/features/jobs/presentation/pages/job_detail_page.dart';
import 'package:jobdun/features/legal/domain/legal_document.dart';
import 'package:jobdun/features/legal/presentation/pages/legal_document_page.dart';
import 'package:jobdun/features/legal/presentation/providers/legal_provider.dart';

class _Guest extends AuthController {
  @override
  AuthState build() => const AuthState();

  @override
  void clearMessages() {}
}

void main() {
  for (final scenario in <String, Widget>{
    'job details': const JobDetailPage(
      args: JobDetailArgs(
        title: 'Test job',
        description: 'Test description',
        rate: r'$25/hr',
        startDate: 'TBD',
        distanceKm: 0,
        isUrgent: false,
      ),
    ),
    'terms': const LegalDocumentPage(type: LegalDocumentType.termsOfService),
    'phone sign in': const PhoneAuthPage(),
  }.entries) {
    testWidgets('${scenario.key} exposes a named Back button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_Guest.new),
            currentUserIdSyncProvider.overrideWithValue(null),
            legalDocumentProvider.overrideWith(
              (ref, type) async => LegalDocument(
                type: type,
                version: '1',
                content: 'Test document',
              ),
            ),
          ],
          child: ScreenUtilInit(
            designSize: const Size(390, 844),
            builder: (_, _) =>
                MaterialApp(theme: AppTheme.light(), home: scenario.value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Back'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      await tester.pump();
      try {
        expect(find.bySemanticsLabel('Back'), findsOneWidget);
      } finally {
        semantics.dispose();
      }
    });
  }
}
