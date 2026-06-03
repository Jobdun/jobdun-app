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

    // A known count reads as a real count — including zero. "—" is reserved for
    // genuinely-not-loaded profile values (null), never a known zero: a dash
    // reads as "still loading", a zero reads as "nothing yet", and the two must
    // not appear side by side in one row (the old `> 0 ? n : '—'` masking did).
    if (isBuilder) {
      final active = builderProfile?.activeJobsCount.toString() ?? '—';
      final total = builderProfile?.totalJobsPosted.toString() ?? '—';
      stats = [
        (active, 'Active jobs'),
        (pendingCount.toString(), 'Applicants'),
        (total, 'Jobs posted'),
      ];
    } else {
      final done = tradeProfile?.jobsCompleted.toString() ?? '—';
      stats = [
        (myAppsCount.toString(), 'Applied'),
        (shortlistedCount.toString(), 'Shortlisted'),
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

// ── Latest-jobs empty state ──────────────────────────────────────────────────
// Compact "nothing yet" card for the home jobs mini-feed. The Browse CTA lives
// in the _PrimaryActionCard above, so this just signals an empty feed rather
// than repeating the action.
class _HomeJobsEmpty extends StatelessWidget {
  const _HomeJobsEmpty();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 20.w,
          vertical: AppSpacing.lg.h,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(AppIcons.search, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.sm.h),
            Text(
              'No jobs nearby yet',
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(4.h),
            Text(
              'New jobs in your area will appear here.',
              style: tt.bodyMedium!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Builder-only "tradies near you" mini-list (#9). Lives in this part file so
// home_page.dart stays near its size budget. Resolves the search origin from
// the builder's service location and shows the top results; SEE ALL / the
// empty CTA route to /discovery, which handles GPS fallback + filters.
class _HomeTradiesSection extends ConsumerStatefulWidget {
  const _HomeTradiesSection();

  @override
  ConsumerState<_HomeTradiesSection> createState() =>
      _HomeTradiesSectionState();
}

class _HomeTradiesSectionState extends ConsumerState<_HomeTradiesSection> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoad();
    });
  }

  // Builder profile loads async — resolve origin + load once geo is present.
  void _maybeLoad() {
    if (_requested) return;
    final bp = ref.read(profileControllerProvider).builderProfile;
    final lat = bp?.serviceLatitude;
    final lng = bp?.serviceLongitude;
    if (lat != null && lng != null) {
      _requested = true;
      ref.read(tradeSearchControllerProvider.notifier).setOrigin(lat, lng);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    ref.listen<ProfileState>(profileControllerProvider, (_, _) => _maybeLoad());
    final tradies = ref
        .watch(tradeSearchControllerProvider)
        .results
        .take(3)
        .toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TRADIES NEAR YOU',
                style: tt.titleLarge!.copyWith(color: c.text1),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/discovery'),
                child: Text(
                  'SEE ALL',
                  style: tt.labelLarge!.copyWith(
                    color: c.action,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Gap(12.h),
          if (tradies.isEmpty)
            const _HomeTradiesEmpty()
          else
            for (var i = 0; i < tradies.length; i++) ...[
              if (i > 0) Gap(9.h),
              DiscoveryTradieTile(
                result: tradies[i],
                onTap: () => context.push('/discovery'),
              ),
            ],
        ],
      ),
    );
  }
}

class _HomeTradiesEmpty extends StatelessWidget {
  const _HomeTradiesEmpty();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: 20.w,
        vertical: AppSpacing.lg.h,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(AppIcons.search, size: AppIconSize.hero.r, color: c.text3),
          Gap(AppSpacing.sm.h),
          Text(
            'NO TRADIES NEARBY',
            style: tt.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          Gap(4.h),
          Text(
            'Widen your search radius.',
            style: tt.bodyMedium!.copyWith(color: c.text3),
            textAlign: TextAlign.center,
          ),
          Gap(AppSpacing.md.h),
          SizedBox(
            width: 200.w,
            child: JButton(
              label: 'WIDEN SEARCH',
              onPressed: () => context.push('/discovery'),
            ),
          ),
        ],
      ),
    );
  }
}
