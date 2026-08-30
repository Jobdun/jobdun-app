part of 'applications_page.dart';

// Empty-state, verified-only toggle, and sample/placeholder data for the
// applications page, split into a `part` so the page file stays under the
// size budget. No behaviour change from the in-file originals.

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, required this.isBuilder});

  final AppTab tab;
  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isAll = tab == AppTab.all;
    final message = isAll
        ? isBuilder
              ? 'No applicants yet.\nPost a job to start receiving applications.'
              : 'No applications yet.\nBrowse open jobs to get started.'
        : 'No ${tab.label.toLowerCase()} applications.';

    // CTA only on the "All" tab — secondary tab empties shouldn't push the
    // user to take an unrelated action.
    final ctaLabel = isAll ? (isBuilder ? 'Post a job' : 'Browse jobs') : null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedEmptyGlyph(
              icon: AppIcons.document,
              motion: EmptyGlyphMotion.bounce,
              size: AppIconSize.hero.r,
              color: c.text3,
            ),
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
                  onPressed: () =>
                      context.go(isBuilder ? '/jobs/create' : '/jobs'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// 2026-08-18 audit (#1): full error state for a failed load with nothing to
// show — mirrors the jobs feed `_PageError` pattern (warning glyph + message
// + RETRY re-triggering the load).
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

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
            Icon(
              AppIcons.warning,
              size: AppIconSize.feature.r,
              color: c.urgent,
            ),
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
                label: 'Retry',
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

// 2026-08-18 audit (#1): dismissible banner for a failed refresh when stale
// data is still on screen — the list stays usable, the failure stays visible.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      color: c.urgentBg,
      padding: EdgeInsets.fromLTRB(20.w, 6.h, 6.w, 6.h),
      child: Row(
        children: [
          Icon(AppIcons.warning, size: AppIconSize.inline.r, color: c.urgentTx),
          Gap(10.w),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall!.copyWith(color: c.urgentTx),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            icon: Icon(
              AppIcons.close,
              size: AppIconSize.inline.r,
              color: c.urgentTx,
            ),
          ),
        ],
      ),
    );
  }
}

// 2026-08-18 audit (#2): makes a non-list state (empty / error) scrollable so
// the surrounding RefreshIndicator can always trigger pull-to-refresh.
class _ScrollableFill extends StatelessWidget {
  const _ScrollableFill({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
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
  jobBudgetAmount: 120,
  jobPricingUnit: 'hourly',
  jobPricingType: 'builder_set',
  quoteAmount: 110,
);

/// The "verified workers only" gate above the applicant list.
///
/// Figma `JobDun-Screens` → Applicants (node 122:5084) promotes it from a bare
/// row to a bordered 16dp card — it changes what the whole list contains, so
/// it reads as a control, not as a caption.
class _VerifiedOnlyToggle extends StatelessWidget {
  const _VerifiedOnlyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(AppIcons.verified, size: AppIconSize.md.r, color: c.actionInk),
          Gap(AppSpacing.sm.w),
          Expanded(
            child: Text(
              'Verified workers only',
              style: tt.titleSmall!.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.0,
                color: c.text1,
              ),
            ),
          ),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
