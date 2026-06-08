import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

/// The single highest-impact thing missing from a profile, plus where to fix
/// it. (S8) We surface exactly one — never a progress ring or a checklist —
/// per the profile-dashboard.md anti-pattern ("just show the missing item").
class ProfileGap {
  const ProfileGap({required this.message, required this.route});

  /// One line, action-framed ("Add your licence to get more jobs.").
  final String message;

  /// Where ADD NOW sends the owner to close the gap.
  final String route;
}

/// Top gap for a tradie, in impact order: licence (trust floor) → portfolio
/// (the most persuasive element) → base suburb (relevance) → trade (matching)
/// → phone (trust). Returns null when nothing high-impact is missing.
ProfileGap? topTradeGap({
  required bool hasLicence,
  required bool hasPortfolio,
  required bool hasSuburb,
  required bool hasTrade,
  required bool phoneVerified,
}) {
  if (!hasLicence) {
    return const ProfileGap(
      message: 'Add your licence to get more jobs.',
      route: '/verification',
    );
  }
  if (!hasPortfolio) {
    return const ProfileGap(
      message: 'Add photos of your work to win more jobs.',
      route: '/profile/edit',
    );
  }
  if (!hasSuburb) {
    return const ProfileGap(
      message: 'Add your base suburb so nearby jobs find you.',
      route: '/profile/edit',
    );
  }
  if (!hasTrade) {
    return const ProfileGap(
      message: 'Set your trade so the right jobs reach you.',
      route: '/profile/edit',
    );
  }
  if (!phoneVerified) {
    return const ProfileGap(
      message: 'Verify your phone so builders trust you.',
      route: '/profile/verify-phone',
    );
  }
  return null;
}

/// Top gap for a builder, in impact order: ABN (legit-business trust floor) →
/// company name → service area (right tradies) → phone. Null when complete.
ProfileGap? topBuilderGap({
  required bool hasAbn,
  required bool hasCompany,
  required bool hasServiceArea,
  required bool phoneVerified,
}) {
  if (!hasAbn) {
    return const ProfileGap(
      message: 'Verify your ABN so tradies trust your jobs.',
      route: '/verification',
    );
  }
  if (!hasCompany) {
    return const ProfileGap(
      message: 'Add your company name.',
      route: '/profile/edit',
    );
  }
  if (!hasServiceArea) {
    return const ProfileGap(
      message: 'Add where you work so the right tradies apply.',
      route: '/profile/edit',
    );
  }
  if (!phoneVerified) {
    return const ProfileGap(
      message: 'Verify your phone so tradies trust you.',
      route: '/profile/verify-phone',
    );
  }
  return null;
}

/// Incomplete-profile nudge: one missing item + an ADD NOW affordance, with the
/// signature 4dp orange left border. Renders nothing when [gap] is null (the
/// profile is complete) so a finished profile shows no congratulatory chrome.
class ProfileIncompleteBanner extends StatelessWidget {
  const ProfileIncompleteBanner({super.key, required this.gap});

  final ProfileGap? gap;

  @override
  Widget build(BuildContext context) {
    final g = gap;
    if (g == null) return const SizedBox.shrink();
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border(left: BorderSide(color: c.action, width: 4)),
      ),
      padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 14.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR PROFILE IS INCOMPLETE',
                  style: tt.labelMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.text1,
                  ),
                ),
                Gap(4.h),
                Text(g.message, style: tt.bodyMedium!.copyWith(color: c.text2)),
              ],
            ),
          ),
          Gap(12.w),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push(g.route),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'ADD NOW',
                  style: tt.labelMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: c.action,
                  ),
                ),
                Gap(2.w),
                Icon(
                  AppIcons.chevronRight,
                  size: AppIconSize.inline.r,
                  color: c.action,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
