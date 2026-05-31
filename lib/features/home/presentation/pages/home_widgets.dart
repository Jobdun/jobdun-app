part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// The page header is now the floating JTopBar SliverAppBar wired directly in
// home_page.dart (LinkedIn-style avatar + search + notifications).

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
            // headlineMedium (24sp) — an on-scale step, not the off-scale 28sp
            // override it used to carry.
            style: tt.headlineMedium!.copyWith(color: c.text1, height: 1.0),
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
                  size: AppIconSize.nav.r,
                  color: c
                      .background, // dark-on-orange — 6.37:1 (was white, 2.80:1)
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
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.md.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Dev-only quick-links to the preview/showcase screens (kDebugMode). Lives in
// this part so home_page.dart stays under the file-size budget.
class _DebugToolsBar extends StatelessWidget {
  const _DebugToolsBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'HOME · FIXED',
                  variant: JButtonVariant.primary,
                  size: JButtonSize.compact,
                  onPressed: () => context.push('/home-preview'),
                ),
              ),
              Gap(8.w),
              Expanded(
                child: JButton(
                  label: 'TOKENS',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.compact,
                  onPressed: () => context.push('/design-preview'),
                ),
              ),
            ],
          ),
          Gap(8.h),
          JButton(
            label: 'LOGO ANIMATION',
            variant: JButtonVariant.secondary,
            size: JButtonSize.compact,
            onPressed: () => context.push('/logo-animation'),
          ),
        ],
      ),
    );
  }
}
