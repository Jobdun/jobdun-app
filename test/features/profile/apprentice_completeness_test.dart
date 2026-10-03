import 'package:flutter_test/flutter_test.dart';
import 'package:jobdun/features/profile/domain/entities/trade_profile.dart';
import 'package:jobdun/features/profile/domain/entities/user_profile.dart';
import 'package:jobdun/features/profile/presentation/providers/profile_provider.dart';
import 'package:jobdun/features/profile/presentation/widgets/profile_incomplete_banner.dart';

void main() {
  const apprentice = TradeProfile(
    id: 'a',
    fullName: 'Alex',
    primaryTrade: 'Carpenter',
    isApprentice: true,
    baseSuburb: 'Sydney',
    about: 'Looking to learn framing.',
    siteTickets: [],
    resumePath: 'a/resume/cv.pdf',
    portfolioUrls: ['photo.jpg'],
  );
  test(
    'complete apprentice does not require licence, rates or a fixed stage',
    () {
      const state = ProfileState(
        profile: UserProfile(id: 'a'),
        tradeProfile: apprentice,
      );
      expect(state.profileCompletenessPct, 100);
      expect(topApprenticeGap(apprentice), isNull);
    },
  );
  test('incomplete apprentice is prompted for resume rather than licence', () {
    const profile = TradeProfile(
      id: 'a',
      fullName: 'Alex',
      primaryTrade: 'Carpenter',
      isApprentice: true,
      baseSuburb: 'Sydney',
      about: 'Learning framing.',
      siteTickets: [],
      portfolioUrls: ['photo.jpg'],
    );
    expect(topApprenticeGap(profile)?.message, contains('resume'));
    expect(
      const ProfileState(
        profile: UserProfile(id: 'a'),
        tradeProfile: profile,
      ).profileCompletenessPct,
      80,
    );
  });
}
