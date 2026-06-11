import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/core/providers/current_user_provider.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/verification/presentation/widgets/manual_upload_sheet.dart';

// Public liability is insurer-issued, so the sheet must capture a free-text
// INSURER. Licence / White Card derive their issuer from the state and must
// NOT show the field.
class _FakeProfileController extends ProfileController {
  _FakeProfileController(this._initial);
  final ProfileState _initial;
  @override
  ProfileState build() => _initial;
}

void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 2200);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  Widget harness({required ManualDocKind kind}) {
    return ProviderScope(
      overrides: [
        currentUserIdSyncProvider.overrideWithValue('u1'),
        profileControllerProvider.overrideWith(
          () => _FakeProfileController(
            ProfileState(
              profile: UserProfile(
                id: 'u1',
                phoneVerifiedAt: DateTime(2026, 5, 14),
              ),
            ),
          ),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showManualUploadSheet(context: context, kind: kind),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('public liability sheet shows an INSURER field', (tester) async {
    await tester.pumpWidget(harness(kind: ManualDocKind.publicLiability));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('INSURER'), findsOneWidget);
    // It is insurer-issued, not state-issued — no STATE / TRADE CLASS.
    expect(find.text('STATE'), findsNothing);
    expect(find.text('TRADE CLASS'), findsNothing);
  });

  testWidgets('trade licence sheet does NOT show an INSURER field', (
    tester,
  ) async {
    await tester.pumpWidget(harness(kind: ManualDocKind.tradeLicence));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('INSURER'), findsNothing);
  });

  testWidgets('white card sheet shows STATE but no INSURER', (tester) async {
    await tester.pumpWidget(harness(kind: ManualDocKind.whiteCard));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('STATE'), findsOneWidget);
    expect(find.text('INSURER'), findsNothing);
    expect(find.text('TRADE CLASS'), findsNothing);
  });
}
