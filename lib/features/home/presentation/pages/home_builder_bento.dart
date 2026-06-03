part of 'home_page.dart';

// Builder home — bento grid (direction #02). Mixed-size tappable tiles: a
// POST A JOB hero, two live stat tiles (active jobs / applicants), a
// "tradies nearby" tile, and FIND A TRADIE / MESSAGES tiles. Replaces the
// builder stats-row + action-card + tradies mini-list. Lives in its own part
// file so home_page.dart stays under the size budget.
class _BuilderBentoGrid extends ConsumerStatefulWidget {
  const _BuilderBentoGrid();

  @override
  ConsumerState<_BuilderBentoGrid> createState() => _BuilderBentoGridState();
}

class _BuilderBentoGridState extends ConsumerState<_BuilderBentoGrid> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeLoad();
    });
  }

  // Resolve the trade-search origin from the builder's service location once
  // the profile (with geo) is available; powers the "tradies nearby" tile.
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
    ref.listen<ProfileState>(profileControllerProvider, (_, _) => _maybeLoad());
    final active =
        ref
            .watch(profileControllerProvider.select((s) => s.builderProfile))
            ?.activeJobsCount ??
        0;
    final applicants = ref.watch(
      applicationsControllerProvider.select((s) => s.pendingIncomingCount),
    );
    final nearby = ref.watch(
      tradeSearchControllerProvider.select((s) => s.results),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Column(
        children: [
          _BentoHero(onTap: () => context.push('/jobs/create')),
          Gap(10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.briefcase,
                  title: 'ACTIVE JOBS',
                  value: active.toString(),
                  onTap: () => context.go('/jobs'),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.applicantsOutline,
                  title: 'APPLICANTS',
                  value: applicants.toString(),
                  accent: true,
                  onTap: () => context.go('/applications'),
                ),
              ),
            ],
          ),
          Gap(10.h),
          _BentoNearbyTile(
            tradies: nearby,
            onTap: () => context.push('/discovery'),
          ),
          Gap(10.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.search,
                  title: 'FIND A TRADIE',
                  onTap: () => context.push('/discovery'),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.chat,
                  title: 'MESSAGES',
                  onTap: () => context.go('/messages'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Full-width orange hero tile. Dark ink on orange (onAction), never white.
class _BentoHero extends StatelessWidget {
  const _BentoHero({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(18.r),
        decoration: BoxDecoration(
          color: c.action,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.addSquare,
              size: AppIconSize.feature.r,
              color: c.onAction,
            ),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'POST A JOB',
                    style: tt.titleLarge!.copyWith(
                      color: c.onAction,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    'Find tradies for your next site',
                    style: tt.bodySmall!.copyWith(color: c.onAction),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Square-ish stat / action tile. `value` present = stat tile (big number);
// absent = action tile (icon + label). `accent` paints the number orange.
class _BentoTile extends StatelessWidget {
  const _BentoTile({
    required this.icon,
    required this.title,
    this.value,
    this.accent = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 116.h,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: AppIconSize.feature.r, color: c.action),
            const Spacer(),
            if (value != null)
              Text(
                value!,
                style: AppTypography.numeric(
                  tt.headlineMedium!,
                ).copyWith(color: accent ? c.action : c.text1, height: 1),
              ),
            Gap(value != null ? 4.h : 0),
            Text(
              title,
              style: tt.titleSmall!.copyWith(
                color: value != null ? c.text3 : c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Full-width "tradies nearby" tile. Shows a count + stacked initials of the
// top results; taps through to /discovery (which owns full search + GPS).
class _BentoNearbyTile extends StatelessWidget {
  const _BentoNearbyTile({required this.tradies, required this.onTap});

  final List<TradeSearchResult> tradies;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final count = tradies.length;
    final top = tradies.take(3).toList();
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(
              AppIcons.location,
              size: AppIconSize.feature.r,
              color: c.action,
            ),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    count > 0
                        ? '$count TRADIES NEARBY'
                        : 'FIND TRADIES NEAR YOU',
                    style: tt.titleMedium!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    count > 0
                        ? 'Tap to browse and filter'
                        : 'Search by trade, rating and distance',
                    style: tt.bodySmall!.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < top.length; i++)
              Padding(
                padding: EdgeInsets.only(left: i == 0 ? 0 : 4.w),
                child: AvatarBlock(
                  initials: _initial(top[i].trade.fullName),
                  size: 30,
                ),
              ),
            Gap(AppSpacing.sm.w),
            Icon(AppIcons.chevronRight, size: AppIconSize.md.r, color: c.text3),
          ],
        ),
      ),
    );
  }

  static String _initial(String name) {
    final t = name.trim();
    return t.isEmpty ? '?' : t.substring(0, 1).toUpperCase();
  }
}
