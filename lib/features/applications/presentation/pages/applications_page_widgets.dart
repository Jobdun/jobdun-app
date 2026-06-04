part of 'applications_page.dart';

// Empty-state, verified-only toggle, and sample/placeholder data for the
// applications page, split into a `part` so the page file stays under the
// size budget. No behaviour change from the in-file originals.

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, required this.isBuilder});

  final AppTab tab;
  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isAll = tab == AppTab.all;
    final message = isAll
        ? isBuilder
              ? 'No applicants yet.\nPost a job to start receiving applications.'
              : 'No applications yet.\nBrowse open jobs to get started.'
        : 'No ${tab.label.toLowerCase()} applications.';

    // CTA only on the "All" tab — secondary tab empties shouldn't push the
    // user to take an unrelated action.
    final ctaLabel = isAll ? (isBuilder ? 'POST A JOB' : 'BROWSE JOBS') : null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedEmptyGlyph(
              icon: AppIcons.document,
              motion: EmptyGlyphMotion.bounce,
              size: AppIconSize.hero.r,
              color: c.text3,
            ),
            Gap(AppSpacing.md.h),
            Text(
              message,
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              Gap(AppSpacing.lg.h),
              SizedBox(
                width: 200.w,
                child: JButton(
                  label: ctaLabel,
                  onPressed: () =>
                      context.go(isBuilder ? '/jobs/create' : '/jobs'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Loading-state placeholder. Real-shaped JobApplication so Skeletonizer can
// mask the card layout into shimmer blocks during initial load.
final _placeholderApp = JobApplication(
  id: 'placeholder',
  jobId: 'placeholder',
  tradeId: 'placeholder',
  builderId: 'placeholder',
  status: ApplicationStatus.pending,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  jobTitle: 'Loading job title placeholder',
  jobSuburb: 'Suburb',
  jobState: 'NSW',
  builderCompanyName: 'Loading company placeholder',
  tradeFullName: 'Loading trade name placeholder',
  tradePrimaryTrade: 'Trade',
  tradeIsVerified: false,
  jobBudgetAmount: 120,
  jobPricingUnit: 'hourly',
  jobPricingType: 'builder_set',
  quoteAmount: 110,
);

class _VerifiedOnlyToggle extends StatelessWidget {
  const _VerifiedOnlyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Verified workers only',
            style: tt.bodyMedium!.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        JSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
