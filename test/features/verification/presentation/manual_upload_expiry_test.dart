import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/verification/presentation/widgets/manual_doc_kind.dart';
import 'package:jobdun/features/verification/presentation/widgets/manual_upload_form.dart';

// U1.1: every kind except an ABN certificate requires an expiry date before
// upload — a credential without one would read "verified" forever, because
// TradePublicCredential.isExpired can never flip without an expires_at.
void main() {
  setUpAll(() async {
    await dotenv.load(
      mergeWith: {
        'SUPABASE_URL': 'https://test.supabase.co',
        'SUPABASE_ANON_KEY': 'test_anon_key',
      },
    );
  });

  group('expiryMissing', () {
    test('blocks a White Card with no expiry', () {
      expect(expiryMissing(ManualDocKind.whiteCard, null), isTrue);
    });

    test('blocks a licence and an insurance policy with no expiry', () {
      expect(expiryMissing(ManualDocKind.tradeLicence, null), isTrue);
      expect(expiryMissing(ManualDocKind.publicLiability, null), isTrue);
    });

    test('passes an ABN certificate with no expiry (ABNs never lapse)', () {
      expect(expiryMissing(ManualDocKind.abnCertificate, null), isFalse);
    });

    test('passes any kind once a date is picked', () {
      expect(expiryMissing(ManualDocKind.whiteCard, DateTime(2028)), isFalse);
    });
  });

  testWidgets('the expiry row renders the validation error when set', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 2200);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    addTearDown(() {
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    final formKey = GlobalKey<FormBuilderState>();
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SingleChildScrollView(
              child: ManualUploadActiveBody(
                kind: ManualDocKind.whiteCard,
                formKey: formKey,
                state: 'NSW',
                onStateChanged: (_) {},
                tradeClass: 'Electrician',
                onTradeClassChanged: (_) {},
                expiry: null,
                expiryError: "Required — this date drives your badge's expiry",
                onPickExpiry: () {},
                prefilledNumber: null,
                pickedFile: null,
                uploading: false,
                attested: false,
                onAttestedChanged: (_) {},
                onCamera: () {},
                onGallery: () {},
                onUpload: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text("Required — this date drives your badge's expiry"),
      findsOneWidget,
    );
  });
}
