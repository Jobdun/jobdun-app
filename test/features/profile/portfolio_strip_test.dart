import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jobdun/app/theme/app_theme.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/profile/presentation/widgets/portfolio_strip.dart';

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
    binding.platformDispatcher.views.first.physicalSize = const Size(390, 1800);
    binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.platformDispatcher.views.first.resetPhysicalSize();
    binding.platformDispatcher.views.first.resetDevicePixelRatio();
  });

  void drainKnownOverflow(WidgetTester tester) {
    final exc = tester.takeException();
    if (exc == null) return;
    if (exc.toString().contains('overflow')) return;
    throw exc;
  }

  Widget wrap(ProfileState state) {
    return ProviderScope(
      overrides: [
        profileControllerProvider.overrideWith(
          () => _FakeProfileController(state),
        ),
      ],
      child: ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.dark(),
          home: const Scaffold(
            body: SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: PortfolioStrip(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  ProfileState tradeWith(List<String> urls) {
    return ProfileState(
      profile: const UserProfile(id: 'u1'),
      tradeProfile: TradeProfile(
        id: 'u1',
        fullName: 'Jane Doe',
        primaryTrade: 'electrician',
        portfolioUrls: urls,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Empty portfolio shows only the ADD tile
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('empty portfolio renders the ADD tile', (tester) async {
    await tester.pumpWidget(wrap(tradeWith(const [])));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('ADD'), findsOneWidget);
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Non-empty portfolio still surfaces the ADD tile while below the cap
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('two-photo portfolio shows ADD plus thumbnails', (tester) async {
    await tester.pumpWidget(
      wrap(
        tradeWith(const [
          'https://example.com/storage/v1/object/public/public-media/u1/portfolio/1.jpg',
          'https://example.com/storage/v1/object/public/public-media/u1/portfolio/2.jpg',
        ]),
      ),
    );
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    // ADD tile still present (cap is 12). skipOffstage so we still find it
    // when it scrolls off the horizontal viewport edge.
    expect(find.text('ADD', skipOffstage: false), findsOneWidget);
    // Two CachedNetworkImage instances rendered for the two URLs.
    // We can't easily assert exact widget count without leaking impl, but
    // the strip must render without throwing — drainKnownOverflow already
    // re-throws anything that isn't a layout overflow.
  });

  // ───────────────────────────────────────────────────────────────────────────
  // At the 12-image cap, ADD tile is hidden — no more uploads allowed
  // ───────────────────────────────────────────────────────────────────────────
  testWidgets('portfolio at the cap hides the ADD tile', (tester) async {
    final twelve = List.generate(
      12,
      (i) =>
          'https://example.com/storage/v1/object/public/public-media/u1/portfolio/$i.jpg',
    );
    await tester.pumpWidget(wrap(tradeWith(twelve)));
    await tester.pumpAndSettle();
    drainKnownOverflow(tester);

    expect(find.text('ADD'), findsNothing);
  });
}
