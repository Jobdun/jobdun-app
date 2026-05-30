part of 'applications_page.dart';

// The application card, split into a `part` so `applications_page.dart` stays
// under the file-size budget. Private, single-use, co-located with the page
// state that builds it. No behaviour change from the in-file original.
class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.app,
    required this.isBuilder,
    this.onUpdateStatus,
    this.onWithdraw,
  });

  final JobApplication app;
  final bool isBuilder;
  final void Function(ApplicationStatus)? onUpdateStatus;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final status = app.status;
    final statusColor = _statusColor(status, c);
    final statusLabel = status.label.toUpperCase();

    final card = _buildCard(context, c, tt, status, statusColor, statusLabel);

    // Swipe affordances on pending rows only. Builders get reject/shortlist;
    // tradies get withdraw. The inline buttons remain — slidable is additive
    // for power users, not a replacement.
    if (status != ApplicationStatus.pending) return card;

    if (isBuilder) {
      return Slidable(
        key: ValueKey('app-${app.id}'),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            _slideAction(
              context: context,
              label: 'REJECT',
              icon: AppIcons.closeCircle,
              backgroundColor: c.urgent,
              onPressed: () => onUpdateStatus?.call(ApplicationStatus.rejected),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.32,
          children: [
            _slideAction(
              context: context,
              label: 'SHORTLIST',
              icon: AppIcons.successCircle,
              backgroundColor: c.available,
              onPressed: () =>
                  onUpdateStatus?.call(ApplicationStatus.shortlisted),
            ),
          ],
        ),
        child: card,
      );
    }

    return Slidable(
      key: ValueKey('app-${app.id}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.32,
        children: [
          _slideAction(
            context: context,
            label: 'WITHDRAW',
            icon: AppIcons.closeBox,
            backgroundColor: c.surfaceRaised,
            foregroundColor: c.text1,
            onPressed: () => onWithdraw?.call(),
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _buildCard(
    BuildContext context,
    JColors c,
    TextTheme tt,
    ApplicationStatus status,
    Color statusColor,
    String statusLabel,
  ) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: status == ApplicationStatus.shortlisted ? c.action : c.border,
          width: status == ApplicationStatus.shortlisted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status bar
          Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card.r),
                topRight: Radius.circular(AppRadius.card.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status chip + date
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.5,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Gap(8.w),
                    Text(
                      _relDate(app.createdAt),
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ],
                ),
                Gap(10.h),
                // ── Job title
                Text(
                  app.jobTitle ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall!.copyWith(
                    fontSize: 18.sp,
                    color: c.text1,
                    height: 1.1,
                  ),
                ),
                Gap(4.h),
                // ── Company / trade name
                Row(
                  children: [
                    Icon(
                      isBuilder ? AppIcons.licence : AppIcons.building,
                      size: 13.r,
                      color: c.text3,
                    ),
                    Gap(6.w),
                    Flexible(
                      child: Text(
                        isBuilder
                            ? (app.tradeFullName ?? '—')
                            : (app.builderCompanyName ?? '—'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
                    if (isBuilder && app.tradeIsVerified == true) ...[
                      Gap(6.w),
                      Icon(AppIcons.verified, size: 13.r, color: c.verified),
                    ],
                  ],
                ),
                // Counterparty trust signal: a trade viewing a builder sees the
                // builder's "Verified business" badge (minimized public
                // projection). Renders nothing when the builder isn't verified.
                if (!isBuilder) ...[
                  Gap(4.h),
                  BuilderVerifiedBadge(userId: app.builderId),
                ],
                Gap(4.h),
                // ── Location
                Row(
                  children: [
                    Icon(AppIcons.location, size: 13.r, color: c.text3),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        [
                          app.jobSuburb,
                          app.jobState,
                        ].whereType<String>().join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium!.copyWith(color: c.text3),
                      ),
                    ),
                    if (app.proposedRate != null) ...[
                      Gap(8.w),
                      Text(
                        '\$${app.proposedRate!.toStringAsFixed(0)}${app.proposedRateType != null ? '/${app.proposedRateType}' : ''}',
                        style: tt.headlineSmall!.copyWith(
                          fontSize: 15.sp,
                          color: c.action,
                        ),
                      ),
                    ],
                  ],
                ),
                // ── Builder actions (shortlist → hire / reject)
                if (isBuilder && status == ApplicationStatus.pending) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  Row(
                    children: [
                      Expanded(
                        child: JButton(
                          label: 'REJECT',
                          variant: JButtonVariant.secondary,
                          size: JButtonSize.compact,
                          onPressed: () =>
                              onUpdateStatus?.call(ApplicationStatus.rejected),
                        ),
                      ),
                      Gap(AppSpacing.sm.w),
                      Expanded(
                        child: JButton(
                          label: 'SHORTLIST',
                          size: JButtonSize.compact,
                          onPressed: () => onUpdateStatus?.call(
                            ApplicationStatus.shortlisted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isBuilder && status == ApplicationStatus.shortlisted) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  GestureDetector(
                    onTap: () => onUpdateStatus?.call(ApplicationStatus.hired),
                    child: Container(
                      width: double.infinity,
                      height: 34.h,
                      decoration: BoxDecoration(
                        color: c.verified,
                        borderRadius: BorderRadius.circular(AppRadius.btn.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HIRE THIS TRADIE',
                        style: tt.labelMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.white, // intentional: white-on-action
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Trade: withdraw pending
                if (!isBuilder && status == ApplicationStatus.pending) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  GestureDetector(
                    onTap: onWithdraw,
                    child: Text(
                      'Withdraw application',
                      style: tt.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.text3,
                        decoration: TextDecoration.underline,
                        decorationColor: c.text3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SlidableAction _slideAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    Color? foregroundColor,
    required VoidCallback onPressed,
  }) {
    final c = context.c;
    return SlidableAction(
      onPressed: (_) {
        HapticFeedback.lightImpact();
        onPressed();
      },
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor ?? c.onAction,
      icon: icon,
      label: label,
      autoClose: true,
    );
  }

  static Color _statusColor(ApplicationStatus s, JColors c) => switch (s) {
    ApplicationStatus.pending => c.action,
    ApplicationStatus.shortlisted => c.available,
    ApplicationStatus.hired => c.verified,
    ApplicationStatus.rejected => c.urgent,
    ApplicationStatus.withdrawn => c.text3,
    ApplicationStatus.declinedByTrade => c.text3,
  };

  static String _relDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
