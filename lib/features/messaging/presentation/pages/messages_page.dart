import '../../../../core/widgets/feature_scaffold_page.dart';

class MessagesPage extends FeatureScaffoldPage {
  const MessagesPage({super.key})
      : super(
          title: 'Messages',
          subtitle: 'Job-specific conversation threads and unread indicators.',
          bullets: const [
            'Builder-to-trade chat is part of the first workflow shell.',
            'Realtime Supabase subscriptions can plug in here next.',
            'Attachment support can stay out of the first pass.',
          ],
        );
}
