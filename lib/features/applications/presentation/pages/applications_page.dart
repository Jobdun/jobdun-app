import '../../../../core/widgets/feature_scaffold_page.dart';

class ApplicationsPage extends FeatureScaffoldPage {
  const ApplicationsPage({super.key})
      : super(
          title: 'Applications',
          subtitle: 'Track your submitted applications and manage incoming ones.',
          bullets: const [
            'Trades can view all submitted applications and their statuses.',
            'Builders can shortlist, accept, or reject applicants.',
            'Application timeline: Pending → Shortlisted → Accepted / Rejected.',
          ],
        );
}
