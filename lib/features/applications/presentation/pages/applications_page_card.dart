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
    this.onMessage,
  });

  final JobApplication app;
  final bool isBuilder;
  final void Function(ApplicationStatus)? onUpdateStatus;
  final VoidCallback? onWithdraw;
  final VoidCallback? onMessage;

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
    final (chipBg, chipTx) = _statusChip(status, c);
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
                          color: chipBg,
                          borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.5,
                            color: chipTx,
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
                  style: tt.titleLarge!.copyWith(color: c.text1, height: 1.1),
                ),
                Gap(4.h),
                // ── Company / trade name
                Row(
                  children: [
                    Icon(
                      isBuilder ? AppIcons.licence : AppIcons.building,
                      size: AppIconSize.micro.r,
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
                      Icon(
                        AppIcons.verified,
                        size: AppIconSize.micro.r,
                        color: c.verified,
                      ),
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
                    Icon(
                      AppIcons.location,
                      size: AppIconSize.micro.r,
                      color: c.text3,
                    ),
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
                  ],
                ),
                // ── Pricing: builder budget vs the applicant's quote.
                // Display only — never ranked, sorted, or compared.
                Gap(8.h),
                Row(
                  children: [
                    Icon(
                      AppIcons.wallet,
                      size: AppIconSize.micro.r,
                      color: c.text3,
                    ),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        _pricingLine(app, isBuilder),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
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
                  Semantics(
                    button: true,
                    label: 'Hire this tradie',
                    child: Material(
                      color: c.verified,
                      borderRadius: BorderRadius.circular(AppRadius.btn.r),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () =>
                            onUpdateStatus?.call(ApplicationStatus.hired),
                        child: Container(
                          width: double.infinity,
                          constraints: BoxConstraints(minHeight: 48.h),
                          alignment: Alignment.center,
                          child: Text(
                            'HIRE THIS TRADIE',
                            style: tt.labelMedium!.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: c
                                  .onAction, // dark-on-fill: white-on-green is 2.28:1 (fails); onAction = 7.83:1
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Builder: open (or start) a chat with the applicant.
                // Available while deciding (pending) and after shortlisting.
                if (isBuilder &&
                    (status == ApplicationStatus.pending ||
                        status == ApplicationStatus.shortlisted)) ...[
                  Gap(AppSpacing.sm.h),
                  JButton(
                    label: 'MESSAGE',
                    variant: JButtonVariant.secondary,
                    size: JButtonSize.compact,
                    onPressed: onMessage,
                  ),
                ],
                // ── Trade: withdraw pending
                if (!isBuilder && status == ApplicationStatus.pending) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  Semantics(
                    button: true,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: onWithdraw,
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          child: Text(
                            AppStrings.withdrawFromJob,
                            style: tt.bodyMedium!.copyWith(
                              fontWeight: FontWeight.w500,
                              color: c.text3,
                              decoration: TextDecoration.underline,
                              decorationColor: c.text3,
                            ),
                          ),
                        ),
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
    ApplicationStatus.pending => c.warning,
    ApplicationStatus.shortlisted => c.available,
    ApplicationStatus.hired => c.verified,
    ApplicationStatus.rejected => c.urgent,
    ApplicationStatus.withdrawn => c.text3,
    ApplicationStatus.declinedByTrade => c.text3,
  };

  // Chip (bg, text) pairs — high-contrast tinted pairs, never the
  // `colour@15% + same-colour text` pattern (lands below AA, grey chips ~2:1).
  // Neutral terminal states use surfaceRaised + text1 (the only AA-safe text
  // on raised). All pairs verified by test/colors_contrast_test.dart.
  static (Color, Color) _statusChip(ApplicationStatus s, JColors c) =>
      switch (s) {
        ApplicationStatus.pending => (c.warningBg, c.warningTx),
        ApplicationStatus.shortlisted => (c.availableBg, c.availableTx),
        ApplicationStatus.hired => (c.verifiedBg, c.verifiedTx),
        ApplicationStatus.rejected => (c.urgentBg, c.urgentTx),
        ApplicationStatus.withdrawn => (c.surfaceRaised, c.text1),
        ApplicationStatus.declinedByTrade => (c.surfaceRaised, c.text1),
      };

  // "Budget $X/unit · Quote $Y/unit", or "Quotes requested · Quote …" when the
  // job asks tradies to quote. Display only — no comparison/ranking logic.
  static String _pricingLine(JobApplication app, bool isBuilder) {
    final suffix = _unitSuffix(app.jobPricingUnit);
    final budget = app.jobPricingType == 'request_quote'
        ? 'Quotes requested'
        : (app.jobBudgetAmount != null
              ? 'Budget \$${app.jobBudgetAmount!.toStringAsFixed(0)}$suffix'
              : 'Budget —');
    final quoteLabel = isBuilder ? 'Quote' : 'Your quote';
    final quote = app.quoteAmount != null
        ? '$quoteLabel \$${app.quoteAmount!.toStringAsFixed(0)}$suffix'
        : '$quoteLabel —';
    return '$budget · $quote';
  }

  static String _unitSuffix(String? unit) => switch (unit) {
    'hourly' => '/hr',
    'sqm' => '/m²',
    'lm' => '/lm',
    _ => '',
  };

  static String _relDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}
