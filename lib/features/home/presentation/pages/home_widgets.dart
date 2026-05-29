part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// ── Header ─────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.isBuilder, required this.location});

  final bool isBuilder;
  final String location;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  // Same `tab` size (24sp Oswald w600) as Jobs / Applications
                  // / Messages so the four bottom-nav landings render with
                  // identical chrome. The previous `hero` (32sp) was a
                  // landing-page emphasis the bottom nav already provides,
                  // and made the title visibly inconsistent when swiping
                  // between tabs.
                  title: isBuilder ? 'Find a tradie' : 'Jobs nearby',
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(AppIcons.location, size: 12.r, color: c.text2),
                    Gap(4.w),
                    Expanded(
                      child: Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall!.copyWith(
                          letterSpacing: 0.02 * 11,
                          color: c.text2,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Gap(12.w),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 34.r,
              height: 34.r,
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                border: Border.all(color: c.border),
              ),
              child: Icon(AppIcons.notification, size: 18.r, color: c.text2),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats Row ──────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.isBuilder,
    required this.pendingCount,
    required this.myAppsCount,
    required this.shortlistedCount,
    this.builderProfile,
    this.tradeProfile,
  });

  final bool isBuilder;
  final BuilderProfile? builderProfile;
  final TradeProfile? tradeProfile;
  final int pendingCount;
  final int myAppsCount;
  final int shortlistedCount;

  @override
  Widget build(BuildContext context) {
    final List<(String, String)> stats;

    if (isBuilder) {
      final active = builderProfile?.activeJobsCount.toString() ?? '—';
      final total = builderProfile?.totalJobsPosted.toString() ?? '—';
      stats = [
        (active, 'Active jobs'),
        (pendingCount > 0 ? pendingCount.toString() : '—', 'Applicants'),
        (total, 'Jobs posted'),
      ];
    } else {
      final done = tradeProfile?.jobsCompleted.toString() ?? '—';
      stats = [
        (myAppsCount > 0 ? myAppsCount.toString() : '—', 'Applied'),
        (
          shortlistedCount > 0 ? shortlistedCount.toString() : '—',
          'Shortlisted',
        ),
        (done, 'Jobs done'),
      ];
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: List.generate(stats.length, (i) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : AppSpacing.sm.w),
              child: _StatCard(value: stats[i].$1, label: stats[i].$2),
            ),
          );
        }),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: tt.headlineSmall!.copyWith(
              fontSize: 28.sp,
              color: c.text1,
              height: 1.0,
            ),
          ),
          Gap(2.h),
          Text(
            label,
            style: tt.bodySmall!.copyWith(
              fontWeight: FontWeight.w400,
              color: c.text3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Primary Action Card ────────────────────────────────────────────────────────

class _PrimaryActionCard extends StatelessWidget {
  const _PrimaryActionCard({required this.isBuilder});

  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: () =>
            isBuilder ? context.push('/jobs/create') : context.go('/jobs'),
        child: Container(
          padding: EdgeInsets.all(20.r),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: c.action,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: Icon(
                  isBuilder ? AppIcons.addSquare : AppIcons.search,
                  size: 22.r,
                  color: Colors.white, // intentional: white-on-action
                ),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isBuilder ? 'Post a new job' : 'Browse open jobs',
                      style: tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                    Gap(2.h),
                    Text(
                      isBuilder
                          ? 'Find skilled tradies for your next site'
                          : 'Construction work near you',
                      style: tt.bodyMedium!.copyWith(color: c.text3),
                    ),
                  ],
                ),
              ),
              Icon(AppIcons.chevronRight, size: 20.r, color: c.text3),
            ],
          ),
        ),
      ),
    );
  }
}
