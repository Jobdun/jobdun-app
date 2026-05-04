import '../../../../core/widgets/feature_scaffold_page.dart';

class ProfilePage extends FeatureScaffoldPage {
  const ProfilePage({super.key})
      : super(
          title: 'Profile',
          subtitle: 'Builder, trade, or admin identity setup and account details.',
          bullets: const [
            'Builder profile fields: company, address, ABN/ACN, contact.',
            'Trade profile fields: category, skills, licences, availability.',
            'Ratings and verification badges can surface here.',
          ],
          navigationIndex: 3,
        );
}
