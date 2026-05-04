import '../../../../core/widgets/feature_scaffold_page.dart';

class JobsPage extends FeatureScaffoldPage {
  const JobsPage({super.key})
      : super(
          title: 'Jobs',
          subtitle: 'Open, assigned, and in-progress work will live here.',
          bullets: const [
            'Search and filter by trade, location, and budget.',
            'Review job status from draft through completion.',
            'Create a builder-focused post flow next.',
          ],
          navigationIndex: 1,
        );
}
