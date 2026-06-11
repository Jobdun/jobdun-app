part of 'home_page.dart';

// Builder home — Action Deck (2026-06-11, twin of the shipped tradie deck):
// an applicants hero ("the decision waiting on you"), the POST A JOB bar,
// the shared DeckStrip micro-strip, then the map preview + find/messages
// row. Replaces the bento stat tiles that buried applicants as a number.
// Lives in its own part file so home_page.dart stays under the size budget.
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
          // Hero = the decision waiting on the builder. Hidden at zero —
          // no fake urgency (honest-copy rule).
          if (applicants > 0) ...[
            _ApplicantsHero(count: applicants),
            Gap(10.h),
          ],
          _BentoHero(onTap: () => context.push('/jobs/create')),
          Gap(10.h),
          DeckStrip(
            cells: [
              (value: activeLoading ? '—' : active.toString(), label: 'ACTIVE'),
              (
                value: applicantsLoading ? '—' : applicants.toString(),
                label: 'APPLICANTS',
              ),
              (
                value:
                    ref
                        .watch(
                          profileControllerProvider.select(
                            (s) => s.builderProfile?.totalJobsPosted,
                          ),
                        )
                        ?.toString() ??
                    '—',
                label: 'POSTED',
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

/// Builder Action Deck hero — "N NEW APPLICANTS WAITING", the decision the
/// builder opened the app for. Shows the newest applicant's job title when
/// available; never renders at zero. Single caller above.
class _ApplicantsHero extends ConsumerWidget {
  const _ApplicantsHero({required this.count});

  final int count;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final newest = ref.watch(
      applicationsControllerProvider.select(
        (s) => s.incomingApplications.isEmpty
            ? null
            : s.incomingApplications.first.jobTitle,
      ),
    );
    final title = newest == null || newest.trim().isEmpty
        ? '$count NEW APPLICANT${count == 1 ? '' : 'S'} WAITING'
        : '$count NEW APPLICANT${count == 1 ? '' : 'S'} · '
              '${newest.trim().toUpperCase()}';
    return Semantics(
      button: true,
      label: '$count new applicants waiting. Opens applicants.',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        onTap: () => context.go('/applications'),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: c.actionBg,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.action.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT: $title',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall!.copyWith(
                  fontFamily: tt.titleLarge!.fontFamily,
                  letterSpacing: 0.5,
                  color: c.actionInk,
                ),
              ),
              Gap(3.h),
              Text(
                'Tap to review and shortlist — oldest first.',
                style: tt.bodySmall!.copyWith(color: c.text2),
              ),
            ],
          ),
        ),
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

// Action tile (icon + label) — stat duty moved to the shared DeckStrip,
// so the tile is navigation-only now.
class _BentoTile extends StatelessWidget {
  const _BentoTile({required this.icon, required this.title, this.onTap});

  final IconData icon;
  final String title;
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
            Text(
              title,
              style: tt.titleSmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
