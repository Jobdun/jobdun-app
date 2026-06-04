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
      if (!mounted) return;
      _maybeLoad();
      // Pull the incoming-applicant count for the home tile (nothing else
      // loads it on this screen, so it would otherwise sit at 0).
      final me = ref.read(currentUserIdSyncProvider);
      if (me != null) {
        ref
            .read(applicationsControllerProvider.notifier)
            .loadIncomingApplications(me);
      }
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
    // Real count of the builder's live (open + filled) jobs. The old
    // builderProfile.activeJobsCount read a non-existent DB column → always 0.
    final activeAsync = ref.watch(builderActiveJobsCountProvider);
    final active = activeAsync.asData?.value ?? 0;
    final activeLoading = activeAsync.isLoading;
    final applicants = ref.watch(
      applicationsControllerProvider.select((s) => s.pendingIncomingCount),
    );
    // Shimmer the stat tiles only on first load (loading + nothing cached) so
    // they don't flash 0 → real, and don't re-shimmer on background refresh.
    final applicantsLoading = ref.watch(
      applicationsControllerProvider.select(
        (s) => s.isLoading && s.incomingApplications.isEmpty,
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Column(
        children: [
          _BentoHero(onTap: () => context.push('/jobs/create')),
          Gap(10.h),
          Row(
            children: [
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.briefcase,
                  title: 'ACTIVE JOBS',
                  value: active.toString(),
                  loading: activeLoading,
                  onTap: () => context.go('/jobs'),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: _BentoTile(
                  icon: AppIcons.applicantsOutline,
                  title: 'APPLICANTS',
                  value: applicants.toString(),
                  loading: applicantsLoading,
                  accent: true,
                  onTap: () => context.go('/applications'),
                ),
              ),
            ],
          ),
          Gap(10.h),
          // Map preview → full-screen tradie map (taps through to /discovery/map).
          const TradeMapPreview(),
          Gap(10.h),
          Row(
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
    this.loading = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? value;
  final bool accent;
  // First-load shimmer for stat tiles — masks a placeholder number instead of
  // flashing 0 before the real count resolves.
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 116.h,
        padding: EdgeInsets.all(14.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: JSkeletonList(
          enabled: loading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: AppIconSize.feature.r, color: c.action),
              const Spacer(),
              if (value != null)
                Text(
                  loading ? '00' : value!,
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
      ),
    );
  }
}
