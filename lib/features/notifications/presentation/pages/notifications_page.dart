import '../../../../core/widgets/feature_scaffold_page.dart';

class NotificationsPage extends FeatureScaffoldPage {
  const NotificationsPage({super.key})
    : super(
        title: 'Notifications',
        subtitle:
            'Stay updated with job activity, messages, and verifications.',
        bullets: const [
          'New job posts, application updates, and message alerts.',
          'Verification approval and rejection notices.',
          'Job status change notifications.',
        ],
      );
}
