part of 'home_page.dart';

// Builder home, rebuilt on the Figma **Homepage** section (`JobDun-Screens`
// node 64:2088, frames 64:2403 / 80:4529).
//
// Shape: a three-up figure row, the live map promo, the Post-a-job CTA, then
// a two-up of Find a Tradie / Applicants. 16dp page padding, 24dp between
// sections — the mock's own rhythm, replacing the old 20/10.
//
// What the mock retired from the previous Action Deck:
//   • `_ApplicantsHero` — the "N NEW APPLICANTS WAITING" banner. The count now
//     reads twice on the screen (orange in the figure row, and as its own
//     card), so the banner was saying a third time what two elements already
//     said.
//   • `DeckStrip` — superseded by `JStatsRow`, which carries the same three
//     figures at the mock's weight.
//   • The MESSAGES tile — the mock spends that slot on Applicants. Messages
//     keeps its dock tab.
//
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
      // Pull the incoming-applicant count for the figure row (nothing else
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
  // the profile (with geo) is available; powers the map promo's pins.
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
    // P6, 2026-08-18 audit: a failed load renders '—' (unknown), never a
    // real-looking 0. A stale value survives a refresh error via `.value`.
    final activeAsync = ref.watch(builderActiveJobsCountProvider);
    final active = activeAsync.value;
    final activeLoading = activeAsync.isLoading;
    final applicants = ref.watch(
      applicationsControllerProvider.select((s) => s.pendingIncomingCount),
    );
    // Only show '—' on first load (loading + nothing cached) so the figure
    // doesn't flash 0 → real, and doesn't blank on background refresh.
    final applicantsLoading = ref.watch(
      applicationsControllerProvider.select(
        (s) => s.isLoading && s.incomingApplications.isEmpty,
      ),
    );
    final posted = ref.watch(
      profileControllerProvider.select(
        (s) => s.builderProfile?.totalJobsPosted,
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, AppSpacing.lg.h),
      child: Column(
        children: [
          JStatsRow(
            stats: [
              JStat(
                // P6, 2026-08-18 audit: error → unknown '—', not 0.
                value: activeLoading ? '—' : active?.toString() ?? '—',
                label: 'Active',
              ),
              JStat(
                value: applicantsLoading ? '—' : applicants.toString(),
                label: 'Applicants',
              ),
              JStat(value: posted?.toString() ?? '—', label: 'Posted'),
            ],
          ),
          Gap(16.h),
          // Live map + the mock's promo copy → full-screen tradie map.
          const TradeMapPreview(),
          Gap(24.h),
          JButton(
            label: 'Post a job',
            icon: AppIcons.add,
            onPressed: () => context.push('/jobs/create'),
          ),
          Gap(24.h),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: HomeQuickActionCard(
                    icon: AppIcons.search,
                    title: 'Find a Tradie',
                    description: 'Discover jobs near you',
                    onTap: () => context.push('/discovery'),
                  ),
                ),
                Gap(16.w),
                Expanded(
                  child: HomeQuickActionCard(
                    icon: AppIcons.applicantsOutline,
                    title: 'Applicants',
                    description: 'Manage and review applicants',
                    onTap: () => context.go('/applications'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
