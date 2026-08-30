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
    required this.verificationsKnown,
  });

  final JobApplication app;
  final TradeProfile? profile;

  /// Verified licence / ABN rows (null = not verified — only meaningful when
  /// [verificationsKnown] is true). Full rows, not booleans, so the chips can
  /// show provenance on tap (U2).
  final Verification? licenceVerif;
  final Verification? abnVerif;

  /// 2026-08-18 audit (#6): false while the verifications load is pending or
  /// failed — the chips render NOTHING then, so an unknown state never reads
  /// as "not verified".
  final bool verificationsKnown;

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

    // 2026-08-18 audit (#6): render the verification chips only once the load
    // has produced data — loading/error is UNKNOWN, never "not verified".
    final chips = <Widget>[
      if (verificationsKnown) ...[
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
          const TrustChip(label: 'Verified', state: TrustChipState.verified),
      ],
      // Approved White Card / public liability — counterparty trust signals
      // from the supplementary-credentials projection.
      TradeCredentialBadges(userId: app.tradeId),
      if (rating != null && ratingCount > 0)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.starFilled, size: AppIconSize.micro.r, color: c.star),
            Gap(3.w),
            Text(
              '${rating.toStringAsFixed(1)} ($ratingCount)',
              style: AppTypography.numeric(
                tt.bodySmall!,
              ).copyWith(fontWeight: FontWeight.w700, color: c.text1),
            ),
          ],
        ),
    ];

    // Figma `JobDun-Screens` → Applicant (node 124:5938) opens on a bordered
    // identity card: 40dp avatar, name, trade. The trust chips are ours — they
    // hang under that row rather than displacing it.
    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Hero(
                tag: 'applicant-avatar:${app.id}',
                child: AvatarBlock(
                  initials: _initials(app.tradeFullName),
                  imageUrl: app.tradeAvatarUrl,
                  size: 40,
                  circle: true,
                ),
              ),
              Gap(AppSpacing.sm.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.tradeFullName ?? 'Tradesperson',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: c.text1,
                      ),
                    ),
                    Gap(AppSpacing.xs.h),
                    Text(
                      loc.isEmpty ? trade : '$trade · $loc',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall!.copyWith(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.4,
                        color: c.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Gap(12.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: chips,
          ),
        ],
      ),
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

// Their quote for THIS job, beside the budget the builder set for it.
//
// Figma `JobDun-Screens` → Applicant (node 124:6143) puts the two figures
// side by side in a tinted orange card, split by a hairline: the comparison IS
// the content, so neither number gets to be a caption on the other.
class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.app});

  final JobApplication app;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final suffix = _unitSuffix(app.jobPricingUnit);
    final quote = app.quoteAmount != null
        ? '\$${app.quoteAmount!.toStringAsFixed(0)}$suffix'
        : '—';
    final String budgetLabel;
    final String budgetValue;
    if (app.jobPricingType == 'request_quote') {
      budgetLabel = 'Your budget';
      budgetValue = 'Quotes asked';
    } else if (app.jobBudgetAmount != null) {
      budgetLabel = 'Your budget';
      budgetValue = '\$${app.jobBudgetAmount!.toStringAsFixed(0)}$suffix';
    } else {
      budgetLabel = 'Your budget';
      budgetValue = '—';
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: BoxDecoration(
        color: c.actionBg,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.action),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _Figure(
                label: 'Their quote · this job',
                value: quote,
                // Orange as ink on a tinted ground → actionInk, not action.
                valueColor: c.actionInk,
              ),
            ),
            Container(width: 1, height: 35.h, color: c.action),
            Expanded(
              child: _Figure(label: budgetLabel, value: budgetValue),
            ),
          ],
        ),
      ),
    );
  }
}

/// One label-over-number cell. Used by [_QuoteBlock]; [_Stat] is its
/// number-over-label twin in the stats card.
class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: tt.bodySmall!.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.0,
            color: c.text1,
          ),
        ),
        Gap(AppSpacing.xs.h),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(tt.titleMedium!).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: valueColor ?? c.text1,
          ),
        ),
      ],
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
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm.w,
        vertical: AppSpacing.md.h,
      ),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Center(
                  child: Container(width: 1, height: 35.h, color: c.border),
                ),
              Expanded(
                child: _Stat(label: stats[i].$1, value: stats[i].$2),
              ),
            ],
          ],
        ),
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
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.numeric(tt.titleMedium!).copyWith(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            height: 1.2,
            color: c.text1,
          ),
        ),
        Gap(AppSpacing.xs.h),
        Text(
          label,
          textAlign: TextAlign.center,
          style: tt.bodySmall!.copyWith(
            fontWeight: FontWeight.w400,
            letterSpacing: 0,
            height: 1.0,
            color: c.text1,
          ),
        ),
      ],
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
