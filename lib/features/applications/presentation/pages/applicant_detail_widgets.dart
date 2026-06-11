part of 'applicant_detail_page.dart';

// Sections for the applicant detail screen, split into a `part` so the page
// stays under the file-size budget. Private, single-use, co-located.

// Avatar + trade/location + verification badges + rating.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.app,
    required this.profile,
    required this.licenceVerif,
    required this.abnVerif,
  });

  final JobApplication app;
  final TradeProfile? profile;

  /// Verified licence / ABN rows (null = not verified or still loading).
  /// Full rows, not booleans, so the chips can show provenance on tap (U2).
  final Verification? licenceVerif;
  final Verification? abnVerif;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final loc = [
      profile?.baseSuburb,
      profile?.baseState,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');
    final trade = app.tradePrimaryTrade ?? 'Tradesperson';
    final rating = profile?.averageRating;
    final ratingCount = profile?.ratingCount ?? 0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Hero(
          tag: 'applicant-avatar:${app.id}',
          child: AvatarBlock(
            initials: _initials(app.tradeFullName),
            imageUrl: app.tradeAvatarUrl,
            size: 56,
            circle: true,
          ),
        ),
        Gap(14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name — the primary identity, prominent. (The app bar shows it
              // too, but the header body must lead with WHO this is.)
              Text(
                app.tradeFullName ?? 'Tradesperson',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.titleLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text1,
                  height: 1.1,
                ),
              ),
              Gap(2.h),
              Text(
                loc.isEmpty ? trade : '$trade · $loc',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: c.text2,
                ),
              ),
              Gap(8.h),
              Wrap(
                spacing: 6.w,
                runSpacing: 6.h,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (licenceVerif != null)
                    TrustChip(
                      label: 'Licence',
                      state: TrustChipState.verified,
                      onTap: () => _openLicenceDetail(context, licenceVerif!),
                    ),
                  if (abnVerif != null)
                    TrustChip(
                      label: 'ABN',
                      state: TrustChipState.verified,
                      onTap: () => _openAbnDetail(context, abnVerif!),
                    ),
                  if (licenceVerif == null &&
                      abnVerif == null &&
                      app.tradeIsVerified == true)
                    // Legacy flag only — no row to show provenance from.
                    const TrustChip(
                      label: 'Verified',
                      state: TrustChipState.verified,
                    ),
                  // Approved White Card / public liability — counterparty trust
                  // signals from the supplementary-credentials projection.
                  TradeCredentialBadges(userId: app.tradeId),
                  if (rating != null && ratingCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.starFilled,
                          size: AppIconSize.micro.r,
                          color: c.star,
                        ),
                        Gap(3.w),
                        Text(
                          '${rating.toStringAsFixed(1)} ($ratingCount)',
                          style: tt.bodySmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// U2.2: provenance sheets for the licence/ABN chips — the same honesty the
// receipts card shows ("as at" snapshot date, register checked, expiry).
void _openLicenceDetail(BuildContext context, Verification v) {
  final state = v.licenceState;
  final asAt = v.detailCapturedAt ?? v.verifiedAt;
  showCredentialDetailSheet(
    context,
    title: 'Trade licence',
    blurb:
        'Licence to carry out regulated trade work, checked against the '
        'public register.',
    rows: [
      (
        icon: AppIcons.verified,
        text: state == null || state.isEmpty
            ? "Checked against the state regulator's public register"
            : "Checked against $state Fair Trading's public register",
      ),
      if ((v.licenceTradeClass ?? '').isNotEmpty)
        (icon: AppIcons.licence, text: v.licenceTradeClass!),
      if (asAt != null)
        (icon: AppIcons.calendar, text: 'As at ${StringUtils.fmtDate(asAt)}'),
      if (v.expiresAt != null)
        (
          icon: AppIcons.clock,
          text: 'Expires ${StringUtils.fmtDate(v.expiresAt!)}',
        ),
    ],
  );
}

void _openAbnDetail(BuildContext context, Verification v) {
  final asAt = v.detailCapturedAt ?? v.verifiedAt;
  showCredentialDetailSheet(
    context,
    title: 'Business (ABN)',
    blurb:
        'Active Australian Business Number, checked against the '
        'Australian Business Register.',
    rows: [
      (
        icon: AppIcons.verified,
        text: 'Checked against the Australian Business Register',
      ),
      if ((v.abnEntityName ?? '').trim().isNotEmpty)
        (icon: AppIcons.building, text: v.abnEntityName!.trim()),
      if (v.gstRegistered == true)
        (icon: AppIcons.check, text: 'GST registered'),
      if (asAt != null)
        (icon: AppIcons.calendar, text: 'As at ${StringUtils.fmtDate(asAt)}'),
    ],
  );
}

// "Their quote · this job" vs the builder's budget.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.app});

  final JobApplication app;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final suffix = _unitSuffix(app.jobPricingUnit);
    final quote = app.quoteAmount != null
        ? '\$${app.quoteAmount!.toStringAsFixed(0)}$suffix'
        : '—';
    final String budgetLabel;
    if (app.jobPricingType == 'request_quote') {
      budgetLabel = "You asked\nfor quotes";
    } else if (app.jobBudgetAmount != null) {
      budgetLabel =
          'vs your\n\$${app.jobBudgetAmount!.toStringAsFixed(0)}$suffix budget';
    } else {
      budgetLabel = '';
    }

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: c.action.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.action.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('THEIR QUOTE · THIS JOB'),
          Gap(AppSpacing.sm.h),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                quote,
                style: tt.headlineLarge!.copyWith(
                  color: c.action,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (budgetLabel.isNotEmpty)
                Text(
                  budgetLabel,
                  textAlign: TextAlign.right,
                  style: tt.bodySmall!.copyWith(color: c.text3, height: 1.3),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// Crew / experience / service-radius — real trade_profiles columns only.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.profile});

  final TradeProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stats = <(String, String)>[
      ('Crew', '${profile.crewSize}'),
      if (profile.yearsExperience != null)
        ('Experience', '${profile.yearsExperience} yrs'),
      ('Service radius', '${profile.serviceRadiusKm} km'),
    ];
    return Container(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) Container(width: 1, height: 30.h, color: c.border),
            Expanded(
              child: _Stat(label: stats[i].$1, value: stats[i].$2),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          value,
          style: tt.titleLarge!.copyWith(
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(2.h),
        Text(
          label.toUpperCase(),
          style: tt.labelSmall!.copyWith(letterSpacing: 0.5, color: c.text3),
        ),
      ],
    );
  }
}

// Bottom action bar — MESSAGE is always primary; the state-specific action
// (shortlist / hire) leads when it matters; reject stays available.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.status,
    required this.onMessage,
    required this.onShortlist,
    required this.onReject,
    required this.onHire,
  });

  final ApplicationStatus status;
  final VoidCallback onMessage;
  final VoidCallback onShortlist;
  final VoidCallback onReject;
  final VoidCallback onHire;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    // MESSAGE supports the decision — secondary, on its own full-width row so
    // the label is never squeezed. REJECT is the destructive secondary.
    final messageSecondary = JButton(
      label: 'MESSAGE',
      icon: AppIcons.chat,
      variant: JButtonVariant.secondary,
      size: JButtonSize.compact,
      onPressed: onMessage,
    );
    final reject = JButton(
      label: 'REJECT',
      variant: JButtonVariant.secondary,
      size: JButtonSize.compact,
      onPressed: onReject,
    );

    final Widget body;
    if (status == ApplicationStatus.pending) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'SHORTLIST',
                  size: JButtonSize.compact,
                  onPressed: onShortlist,
                ),
              ),
              Gap(8.w),
              Expanded(child: reject),
            ],
          ),
          Gap(8.h),
          Row(children: [Expanded(child: messageSecondary)]),
        ],
      );
    } else if (status == ApplicationStatus.shortlisted) {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'HIRE',
                  size: JButtonSize.compact,
                  onPressed: onHire,
                ),
              ),
              Gap(8.w),
              Expanded(child: reject),
            ],
          ),
          Gap(8.h),
          Row(children: [Expanded(child: messageSecondary)]),
        ],
      );
    } else {
      // hired / rejected / withdrawn / declined — terminal: MESSAGE is now the
      // sole action, so it leads as the primary CTA.
      body = Row(
        children: [
          Expanded(
            child: JButton(
              label: 'MESSAGE',
              icon: AppIcons.chat,
              size: JButtonSize.compact,
              onPressed: onMessage,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: body,
    );
  }
}

String _initials(String? name) {
  final n = (name ?? '').trim();
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

String _unitSuffix(String? unit) => switch (unit) {
  'hourly' => '/hr',
  'sqm' => '/m²',
  'lm' => '/lm',
  _ => '',
};
