part of 'applicant_detail_page.dart';

// Sections for the applicant detail screen, split into a `part` so the page
// stays under the file-size budget. Private, single-use, co-located.

// Avatar + trade/location + verification badges + rating.
class _DetailHeader extends StatelessWidget {
  const _DetailHeader({
    required this.app,
    required this.profile,
    required this.hasLicence,
    required this.hasAbn,
  });

  final JobApplication app;
  final TradeProfile? profile;
  final bool hasLicence;
  final bool hasAbn;

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
        Container(
          width: 56.r,
          height: 56.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            shape: BoxShape.circle,
            border: Border.all(color: c.border),
          ),
          child: Text(
            _initials(app.tradeFullName),
            style: tt.headlineSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
        ),
        Gap(14.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.isEmpty ? trade : '$trade · $loc',
                style: tt.titleMedium!.copyWith(
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
                  if (hasLicence) const _VBadge('Licence'),
                  if (hasAbn) const _VBadge('ABN'),
                  if (!hasLicence && !hasAbn && app.tradeIsVerified == true)
                    const _VBadge('Verified'),
                  if (rating != null && ratingCount > 0)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          AppIcons.starFilled,
                          size: AppIconSize.micro.r,
                          color: c.warning,
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

class _VBadge extends StatelessWidget {
  const _VBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.verified,
            size: AppIconSize.micro.r,
            color: c.verifiedTx,
          ),
          Gap(3.w),
          Text(
            label.toUpperCase(),
            style: tt.labelSmall!.copyWith(
              letterSpacing: 0.4,
              color: c.verifiedTx,
            ),
          ),
        ],
      ),
    );
  }
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
    final message = JButton(
      label: 'MESSAGE',
      icon: AppIcons.chat,
      size: JButtonSize.compact,
      onPressed: onMessage,
    );

    List<Widget> children;
    if (status == ApplicationStatus.pending) {
      children = [
        Expanded(flex: 5, child: message),
        Gap(8.w),
        Expanded(
          flex: 4,
          child: JButton(
            label: 'SHORTLIST',
            variant: JButtonVariant.secondary,
            size: JButtonSize.compact,
            onPressed: onShortlist,
          ),
        ),
        Gap(8.w),
        Expanded(
          flex: 3,
          child: JButton(
            label: 'REJECT',
            variant: JButtonVariant.secondary,
            size: JButtonSize.compact,
            onPressed: onReject,
          ),
        ),
      ];
    } else if (status == ApplicationStatus.shortlisted) {
      children = [
        Expanded(
          flex: 5,
          child: JButton(
            label: 'HIRE',
            size: JButtonSize.compact,
            onPressed: onHire,
          ),
        ),
        Gap(8.w),
        Expanded(flex: 5, child: message),
        Gap(8.w),
        Expanded(
          flex: 3,
          child: JButton(
            label: 'REJECT',
            variant: JButtonVariant.secondary,
            size: JButtonSize.compact,
            onPressed: onReject,
          ),
        ),
      ];
    } else {
      // hired / rejected / withdrawn / declined — terminal: just message.
      children = [Expanded(child: message)];
    }

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: Row(children: children),
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
