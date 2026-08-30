part of 'builder_listings_view.dart';

// Skeleton / empty / error states and the header CTA for BuilderListingsView.
// The listing card itself lives in `builder_listings_card.dart` — this file
// crossed the 500 LOC ceiling once the card was redrawn on the Figma.

// Full-page error + RETRY for the listings view (P6, 2026-08-18 audit).
// Mirrors the jobs feed `_PageError` pattern (jobs_page_widgets.dart).
class _ListingsError extends StatelessWidget {
  const _ListingsError({required this.onRetry});

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
            Icon(
              AppIcons.warning,
              size: AppIconSize.feature.r,
              color: c.urgent,
            ),
            Gap(AppSpacing.md.h),
            Text(
              "Couldn't load your listings.",
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

class _ListingsSkeleton extends StatelessWidget {
  const _ListingsSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return JSkeletonList(
      enabled: true,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20.w, AppSpacing.sm.h, 20.w, 0),
        itemCount: 4,
        separatorBuilder: (_, _) => Gap(10.h),
        itemBuilder: (_, _) => Container(
          height: 150.h,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
        ),
      ),
    );
  }
}

class _ListingsEmpty extends StatelessWidget {
  const _ListingsEmpty({required this.tab});

  final _Tab tab;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isAll = tab == _Tab.all;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.briefcase, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              isAll ? 'NO LISTINGS YET.' : 'NOTHING HERE.',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              isAll
                  ? 'Post a job to start hiring tradies.'
                  : 'No listings in this status.',
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (isAll) ...[
              Gap(AppSpacing.lg.h),
              JButton(
                label: 'POST A JOB',
                icon: AppIcons.addSquare,
                onPressed: () => context.push('/jobs/create'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact header CTA — Figma `JobDun-Screens` → Manage Listings (node
/// 87:6231): a 32dp orange pill with a 12dp plus and a 12px bold label. Small
/// on purpose: posting is the builder's main verb, but it shares the bar with
/// the screen title, so it earns a pill rather than a full-height button.
class _PostJobButton extends StatelessWidget {
  const _PostJobButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Post a job',
      excludeSemantics: true,
      child: Material(
        color: c.action,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: 32.h,
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppIcons.add, size: 12.r, color: c.onAction),
                Gap(AppSpacing.xs.w),
                Text(
                  'Post a job',
                  style: tt.bodySmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                    height: 1.0,
                    color: c.onAction,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
