part of 'applications_page.dart';

// Empty-state, verified-only toggle, and sample/placeholder data for the
// applications page, split into a `part` so the page file stays under the
// size budget. No behaviour change from the in-file originals.

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, required this.isBuilder});

  final String tab;
  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final message = tab == 'All'
        ? isBuilder
              ? 'No applicants yet.\nPost a job to start receiving applications.'
              : 'No applications yet.\nBrowse open jobs to get started.'
        : 'No $tab applications.';

    // CTA only on the "All" tab — secondary tab empties shouldn't push the
    // user to take an unrelated action.
    final ctaLabel = tab == 'All'
        ? (isBuilder ? 'POST A JOB' : 'BROWSE JOBS')
        : null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.document, size: 48.r, color: c.text3),
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
                  onPressed: () => context.go(isBuilder ? '/jobs' : '/jobs'),
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
  proposedRate: 0,
  proposedRateType: 'hr',
);

// ── Sample mock data (shown when provider returns empty) ───────────────────────

List<JobApplication> _mockApps(bool isBuilder) => [
  JobApplication(
    id: 'mock-1',
    jobId: 'j1',
    tradeId: 't1',
    builderId: 'b1',
    status: ApplicationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    jobTitle: 'Install 3-phase switchboard',
    jobSuburb: 'Surry Hills',
    jobState: 'NSW',
    builderCompanyName: 'Pinnacle Construct',
    tradeFullName: 'Marcus Webb',
    tradePrimaryTrade: 'Electrician',
    tradeIsVerified: true,
    proposedRate: 85,
    proposedRateType: 'hr',
  ),
  JobApplication(
    id: 'mock-2',
    jobId: 'j2',
    tradeId: 't2',
    builderId: 'b1',
    status: ApplicationStatus.shortlisted,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    jobTitle: 'Frame internal walls — Newtown renovation',
    jobSuburb: 'Newtown',
    jobState: 'NSW',
    builderCompanyName: 'BuildRight Pty Ltd',
    tradeFullName: "Sarah O'Brien",
    tradePrimaryTrade: 'Carpenter',
    tradeIsVerified: true,
    proposedRate: 45,
    proposedRateType: 'hr',
  ),
  JobApplication(
    id: 'mock-3',
    jobId: 'j3',
    tradeId: 't3',
    builderId: 'b1',
    status: ApplicationStatus.hired,
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    jobTitle: 'Concrete footings for deck extension',
    jobSuburb: 'Cronulla',
    jobState: 'NSW',
    builderCompanyName: 'Coast & Country Builds',
    tradeFullName: 'Jake Kowalski',
    tradePrimaryTrade: 'Concreter',
    tradeIsVerified: false,
    proposedRate: 75,
    proposedRateType: 'hr',
  ),
];

class _VerifiedOnlyToggle extends StatelessWidget {
  const _VerifiedOnlyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Verified workers only',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: c.action),
      ],
    );
  }
}
