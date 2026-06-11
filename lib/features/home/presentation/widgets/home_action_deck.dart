import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../applications/domain/entities/job_application.dart';
import 'deck_strip.dart';

/// Action Deck (homepage architecture #1, 2026-06-11): answers "where do I
/// stand right now?" before the jobs feed — one hero card for the tradie's
/// live situation plus a one-row stats micro-strip. Replaces the three big
/// stat tiles that pushed the first job below the fold (NN/g: springboard,
/// not dashboard-dump).
class HomeActionDeck extends StatelessWidget {
  const HomeActionDeck({
    super.key,
    required this.applications,
    required this.rating,
  });

  final List<JobApplication> applications;
  final double? rating;

  @override
  Widget build(BuildContext context) {
    final next = _nextUp();
    final applied = applications
        .where(
          (a) =>
              a.status == ApplicationStatus.pending ||
              a.status == ApplicationStatus.shortlisted,
        )
        .length;
    final shortlisted = applications
        .where((a) => a.status == ApplicationStatus.shortlisted)
        .length;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (next != null) ...[_NextUpCard(app: next), Gap(10.h)],
          DeckStrip(
            cells: [
              (value: '$applied', label: 'APPLIED'),
              (value: '$shortlisted', label: 'SHORTLIST'),
              (
                value: rating != null ? rating!.toStringAsFixed(1) : '—',
                label: 'RATING',
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The single most decision-relevant application: a hire beats a
  /// shortlist beats a plain pending. Null when nothing is in flight —
  /// the hero simply doesn't render and the feed rises.
  JobApplication? _nextUp() {
    JobApplication? best;
    int rank(ApplicationStatus s) => switch (s) {
      ApplicationStatus.hired => 3,
      ApplicationStatus.shortlisted => 2,
      ApplicationStatus.pending => 1,
      _ => 0,
    };
    for (final a in applications) {
      if (rank(a.status) == 0) continue;
      if (best == null || rank(a.status) > rank(best.status)) best = a;
    }
    return best;
  }
}

/// "NEXT: …" hero — status eyebrow + job title + one helper line. Tap goes
/// to the Applied tab where the full pipeline lives. Single caller above.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.app});

  final JobApplication app;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (eyebrow, helper) = switch (app.status) {
      ApplicationStatus.hired => (
        'BOOKED',
        'You got it — check the schedule and message the builder.',
      ),
      ApplicationStatus.shortlisted => (
        'SHORTLISTED',
        "You're in the running — the builder is deciding now.",
      ),
      _ => ('APPLIED', 'Awaiting the builder. Keep applying meanwhile.'),
    };
    return Semantics(
      button: true,
      label:
          '$eyebrow: ${app.jobTitle ?? 'your application'}. Opens '
          'applications.',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        onTap: () => context.go('/applications'),
        child: Container(
          padding: EdgeInsets.all(12.r),
          decoration: BoxDecoration(
            color: c.actionBg,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.action.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NEXT: $eyebrow · ${(app.jobTitle ?? 'YOUR APPLICATION').toUpperCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleSmall!.copyWith(
                  fontFamily: tt.titleLarge!.fontFamily,
                  letterSpacing: 0.5,
                  color: c.actionInk,
                ),
              ),
              Gap(3.h),
              Text(helper, style: tt.bodySmall!.copyWith(color: c.text2)),
            ],
          ),
        ),
      ),
    );
  }
}
