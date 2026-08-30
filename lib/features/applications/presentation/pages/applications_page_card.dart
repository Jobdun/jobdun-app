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
    final statusLabel = status.label;

    final card = _buildCard(context, c, tt, status, statusLabel);

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
    String statusLabel,
  ) {
    final (chipBg, chipTx) = _statusChip(status, c);
    final actions = _actions(context, c, tt, status);
    // Figma `JobDun-Screens` → Applicants (node 122:5094): a 16dp-radius card
    // on a hairline, 16dp padding, and a 16dp rhythm between every block
    // inside it. The old 3dp status strip is gone — the pill now carries its
    // own dot, so state is still never colour alone.
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        // One hairline for every state — Figma leans on the status pill and
        // the footer action to tell the states apart, so the old orange
        // shortlisted edge is gone (it competed with the CTA beneath it).
        border: Border.all(color: c.border),
      ),
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status pill + age
          Row(
            children: [
              Flexible(
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 11.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8.r,
                        height: 8.r,
                        decoration: BoxDecoration(
                          color: chipTx,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Gap(AppSpacing.xs.w),
                      Flexible(
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall!.copyWith(
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.0,
                            color: chipTx,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              Gap(AppSpacing.sm.w),
              Text(
                _relDate(app.createdAt),
                style: tt.bodyMedium!.copyWith(height: 1.0, color: c.text1),
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          // ── Job title
          Text(
            app.jobTitle ?? '—',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.2,
              color: c.text1,
            ),
          ),
          Gap(AppSpacing.md.h),
          // ── Who / where / what it pays — one 18dp glyph per line, 12dp apart
          _CardLine(
            icon: isBuilder ? AppIcons.licence : AppIcons.building,
            text: isBuilder
                ? (app.tradeFullName ?? '—')
                : (app.builderCompanyName ?? '—'),
            trailing: isBuilder && app.tradeIsVerified == true
                ? Icon(
                    AppIcons.verified,
                    size: AppIconSize.inline.r,
                    color: c.verified,
                  )
                : null,
          ),
          // Counterparty trust signal: a trade viewing a builder sees the
          // builder's "Verified business" badge (minimized public projection).
          // Renders nothing when the builder isn't verified.
          if (!isBuilder) ...[
            Gap(AppSpacing.sm.h),
            BuilderVerifiedBadge(userId: app.builderId),
          ],
          Gap(12.h),
          _CardLine(
            icon: AppIcons.location,
            text: [app.jobSuburb, app.jobState].whereType<String>().join(', '),
          ),
          Gap(12.h),
          // Pricing: builder budget vs the applicant's quote. Display only —
          // never ranked, sorted, or compared.
          _CardLine(
            icon: AppIcons.wallet,
            text: _pricingLine(app, isBuilder),
            numeric: true,
          ),
          if (actions.isNotEmpty) ...[
            Gap(AppSpacing.md.h),
            Divider(height: 1, color: c.border),
            Gap(AppSpacing.md.h),
            ...actions,
          ],
        ],
      ),
    );
  }

  /// The card's footer actions for [status], already interleaved with their
  /// 16dp gaps. Empty when this state has nothing to act on — the card then
  /// drops its divider too.
  List<Widget> _actions(
    BuildContext context,
    JColors c,
    TextTheme tt,
    ApplicationStatus status,
  ) {
    // ── Builder: triage (shortlist → hire / reject), then message.
    if (isBuilder && status == ApplicationStatus.pending) {
      return [
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'Shortlist',
                size: JButtonSize.compact,
                onPressed: () =>
                    onUpdateStatus?.call(ApplicationStatus.shortlisted),
              ),
            ),
            Gap(AppSpacing.sm.w),
            Expanded(
              child: JButton(
                label: 'Reject',
                variant: JButtonVariant.dangerOutline,
                size: JButtonSize.compact,
                onPressed: () =>
                    onUpdateStatus?.call(ApplicationStatus.rejected),
              ),
            ),
          ],
        ),
        Gap(AppSpacing.md.h),
        _messageButton,
      ];
    }
    if (isBuilder && status == ApplicationStatus.shortlisted) {
      return [
        JButton(
          label: 'Hire this tradie',
          variant: JButtonVariant.successOutline,
          size: JButtonSize.compact,
          onPressed: () => onUpdateStatus?.call(ApplicationStatus.hired),
        ),
        Gap(AppSpacing.md.h),
        _messageButton,
      ];
    }
    // ── Trade: withdraw a pending application.
    if (!isBuilder && status == ApplicationStatus.pending) {
      return [
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
      ];
    }
    // ── Post-hire: rate the other party (builder ⇄ tradie). One review per
    // reviewer per job — DB unique constraint; ReviewCta swaps to a read-only
    // row once submitted.
    if (status == ApplicationStatus.hired) {
      return [
        ReviewCta(
          jobId: app.jobId,
          revieweeId: isBuilder ? app.tradeId : app.builderId,
          revieweeName: isBuilder
              ? (app.tradeFullName ?? 'this tradie')
              : (app.builderCompanyName ?? 'this builder'),
          label: isBuilder ? 'Review tradie' : 'Review builder',
        ),
      ];
    }
    return const [];
  }

  Widget get _messageButton => JButton(
    label: 'Message',
    icon: AppIcons.send,
    variant: JButtonVariant.outline,
    size: JButtonSize.compact,
    onPressed: onMessage,
  );

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
    // 2026-08-18 audit (#7): first minute read "0m ago" and clock skew
    // produced negative values ("-3m ago").
    if (diff.isNegative || diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// One metadata line inside [_AppCard]: an 18dp glyph, an 8dp gutter, then the
/// value — Figma `JobDun-Screens` → Applicants, node 122:5102. [trailing] is
/// the verified seal that rides after the trade's name on that first line.
class _CardLine extends StatelessWidget {
  const _CardLine({
    required this.icon,
    required this.text,
    this.trailing,
    this.numeric = false,
  });

  final IconData icon;
  final String text;
  final Widget? trailing;

  /// Renders the value on the tabular-figure style so budget/quote columns
  /// don't jitter between cards.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final base = tt.bodyLarge!.copyWith(height: 1.0, color: c.text1);
    return Row(
      children: [
        Icon(icon, size: AppIconSize.inline.r, color: c.text2),
        Gap(AppSpacing.sm.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: numeric ? AppTypography.numeric(base) : base,
          ),
        ),
        if (trailing != null) ...[Gap(AppSpacing.sm.w), trailing!],
      ],
    );
  }
}
