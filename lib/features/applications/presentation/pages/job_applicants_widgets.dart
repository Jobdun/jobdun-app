part of 'job_applicants_page.dart';

// Pieces for the Job → Applicants screen, split into a `part` so the page file
// stays under the file-size budget. Private, single-use, co-located.

// Job summary pinned at the top of the screen (layout "A").
class _JobSummaryCard extends StatelessWidget {
  const _JobSummaryCard({required this.args});

  final JobApplicantsArgs args;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            args.title,
            style: tt.titleLarge!.copyWith(color: c.text1, height: 1.15),
          ),
          Gap(10.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: [
              if (args.payLabel != null)
                _SummaryChip(
                  icon: AppIcons.wallet,
                  label: args.payLabel!,
                  accent: true,
                ),
              if (args.locationLabel != null)
                _SummaryChip(
                  icon: AppIcons.location,
                  label: args.locationLabel!,
                ),
              if (args.tradeType != null)
                _SummaryChip(icon: AppIcons.licence, label: args.tradeType!),
              if (args.statusLabel != null)
                _SummaryChip(icon: AppIcons.shield, label: args.statusLabel!),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: accent ? c.action.withValues(alpha: 0.12) : c.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(
          color: accent ? c.action.withValues(alpha: 0.3) : c.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppIconSize.inline.r,
            color: accent ? c.action : c.text3,
          ),
          Gap(6.w),
          Text(
            label,
            style: tt.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
              color: accent ? c.action : c.text2,
            ),
          ),
        ],
      ),
    );
  }
}

// One tappable applicant row → opens the applicant detail.
class _ApplicantRow extends StatelessWidget {
  const _ApplicantRow({required this.app, required this.onTap});

  final JobApplication app;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (chipBg, chipTx) = _statusChipColors(app.status, c);
    final suffix = _unitSuffix(app.jobPricingUnit);
    final quote = app.quoteAmount != null
        ? '\$${app.quoteAmount!.toStringAsFixed(0)}$suffix'
        : '—';
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            _RowAvatar(name: app.tradeFullName),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          app.tradeFullName ?? 'Tradesperson',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                      ),
                      if (app.tradeIsVerified == true) ...[
                        Gap(5.w),
                        Icon(
                          AppIcons.verified,
                          size: AppIconSize.micro.r,
                          color: c.verified,
                        ),
                      ],
                    ],
                  ),
                  Gap(2.h),
                  Text(
                    '${app.tradePrimaryTrade ?? 'Trade'} · Quote $quote',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall!.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            Gap(AppSpacing.sm.w),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: chipBg,
                borderRadius: BorderRadius.circular(AppRadius.chip.r),
              ),
              child: Text(
                app.status.label.toUpperCase(),
                style: tt.labelSmall!.copyWith(
                  letterSpacing: 0.5,
                  color: chipTx,
                ),
              ),
            ),
            Gap(4.w),
            Icon(AppIcons.chevronRight, size: AppIconSize.md.r, color: c.text3),
          ],
        ),
      ),
    );
  }
}

class _RowAvatar extends StatelessWidget {
  const _RowAvatar({this.name});

  final String? name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: 40.r,
      height: 40.r,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Text(
        _initials(name),
        style: tt.titleSmall!.copyWith(
          fontWeight: FontWeight.w700,
          color: c.text1,
        ),
      ),
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

(Color, Color) _statusChipColors(ApplicationStatus s, JColors c) => switch (s) {
  ApplicationStatus.pending => (c.warningBg, c.warningTx),
  ApplicationStatus.shortlisted => (c.availableBg, c.availableTx),
  ApplicationStatus.hired => (c.verifiedBg, c.verifiedTx),
  ApplicationStatus.rejected => (c.urgentBg, c.urgentTx),
  ApplicationStatus.withdrawn => (c.surfaceRaised, c.text1),
  ApplicationStatus.declinedByTrade => (c.surfaceRaised, c.text1),
};

// Shown when the verified-only filter is hiding every applicant — so the list
// reads "N hidden — show all" instead of looking like zero applicants.
class _HiddenNotice extends StatelessWidget {
  const _HiddenNotice({required this.count, required this.onShowAll});

  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.r),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.shield, size: AppIconSize.md.r, color: c.text3),
              Gap(10.w),
              Expanded(
                child: Text(
                  count == 1
                      ? '1 applicant is hidden — only verified workers are shown.'
                      : '$count applicants are hidden — only verified workers are shown.',
                  style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.4),
                ),
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          GestureDetector(
            onTap: onShowAll,
            behavior: HitTestBehavior.opaque,
            child: Text(
              'SHOW ALL APPLICANTS',
              style: tt.labelLarge!.copyWith(
                color: c.action,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// True empty state — no applicants on this job at all.
class _EmptyApplicants extends StatelessWidget {
  const _EmptyApplicants();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 40.h),
      child: Column(
        children: [
          Icon(
            AppIcons.applicantsOutline,
            size: AppIconSize.hero.r,
            color: c.text3,
          ),
          Gap(AppSpacing.md.h),
          Text(
            'No applicants yet',
            style: tt.headlineSmall!.copyWith(color: c.text1),
          ),
          Gap(AppSpacing.sm.h),
          Text(
            'Tradies who apply to this job will show up here.',
            textAlign: TextAlign.center,
            style: tt.bodyMedium!.copyWith(color: c.text3),
          ),
        ],
      ),
    );
  }
}

// Loading placeholder for the skeleton list.
final _placeholderApplicant = JobApplication(
  id: 'placeholder',
  jobId: 'placeholder',
  tradeId: 'placeholder',
  builderId: 'placeholder',
  status: ApplicationStatus.pending,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tradeFullName: 'Loading applicant name',
  tradePrimaryTrade: 'Trade',
  tradeIsVerified: true,
  quoteAmount: 80,
  jobPricingUnit: 'hourly',
);
