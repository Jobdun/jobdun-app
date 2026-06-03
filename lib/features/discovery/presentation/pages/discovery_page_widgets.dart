part of 'discovery_page.dart';

// Private list/state leaf widgets for the discovery page, split into a `part`
// so discovery_page.dart stays under the file-size budget. Single-use helpers
// co-located with their only caller.

// First-page skeleton: five placeholder TradieCards inside JSkeletonList. A
// Column (not ListView) because infinite_scroll_pagination hosts this in a
// non-scrolling SliverFillRemaining that needs intrinsic height.
class _DiscoverySkeleton extends StatelessWidget {
  const _DiscoverySkeleton();

  @override
  Widget build(BuildContext context) {
    return JSkeletonList(
      enabled: true,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: AppSpacing.sm.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 5; i++) ...[
              if (i > 0) Gap(9.h),
              const _TradiePlaceholder(),
            ],
          ],
        ),
      ),
    );
  }
}

// Real-shaped TradieCard fed placeholder data so Skeletonizer masks it into
// shimmer blocks matching the loaded layout.
class _TradiePlaceholder extends StatelessWidget {
  const _TradiePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const TradieCard(
      name: 'Placeholder tradie name',
      trade: 'Electrician',
      suburb: 'Suburb, NSW',
      rating: 4.8,
      jobCount: 12,
      isVerified: true,
      isAvailable: true,
      distanceKm: 2.3,
      initials: 'PT',
    );
  }
}

class _DiscoveryEmpty extends StatelessWidget {
  const _DiscoveryEmpty({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.search, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              'NO TRADIES MATCH',
              style: tt.headlineSmall!.copyWith(color: c.text1),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              'Try a wider radius or fewer filters.',
              style: tt.bodyLarge!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.lg.h),
            SizedBox(
              width: 200.w,
              child: JButton(label: 'CLEAR FILTERS', onPressed: onClear),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryError extends StatelessWidget {
  const _DiscoveryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.warning, size: AppIconSize.feature.r, color: c.urgent),
            Gap(AppSpacing.md.h),
            Text(
              message,
              style: tt.bodyMedium!.copyWith(color: c.urgentTx),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.md.h),
            SizedBox(
              width: 160.w,
              child: JButton(
                label: 'RETRY',
                variant: JButtonVariant.secondary,
                onPressed: onRetry,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
