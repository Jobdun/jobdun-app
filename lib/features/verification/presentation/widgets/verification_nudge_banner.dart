import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../providers/verifications_provider.dart';

/// Persistent dismissible banner that nudges the user toward the wizard.
/// Self-hides when:
///   - the user is fully verified for their role
///   - the user has tapped × this session
///
/// Copy is carrot-not-stick (v2 spec): never blocks anything.
class VerificationNudgeBanner extends ConsumerWidget {
  const VerificationNudgeBanner({super.key, required this.role});

  final NudgeRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dismissed = ref.watch(verificationBannerDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final async = ref.watch(myVerificationsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rows) {
        final summary = role == NudgeRole.trade
            ? summariseForTrade(rows)
            : summariseForBuilder(rows);
        if (summary == VerificationSummary.fullyVerified) {
          return const SizedBox.shrink();
        }
        return _Banner(role: role);
      },
    );
  }
}

enum NudgeRole { trade, builder }

class _Banner extends ConsumerWidget {
  const _Banner({required this.role});
  final NudgeRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final copy = role == NudgeRole.trade
        ? 'Verified workers get hired faster. About a minute.'
        : 'Verified businesses get more applicants. About 15 seconds.';

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 0),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.actionBg,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: c.action.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(AppIcons.shield, color: c.action, size: 20.r),
          Gap(12.w),
          Expanded(
            child: Text(
              copy,
              style: TextStyle(
                fontSize: 13.sp,
                color: c.text1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Gap(8.w),
          InkWell(
            onTap: () => context.push('/verification/wizard'),
            child: Text(
              'Get verified →',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: c.action,
              ),
            ),
          ),
          Gap(8.w),
          IconButton(
            icon: Icon(Icons.close, size: 18.r, color: c.text3),
            onPressed: () => ref
                .read(verificationBannerDismissedProvider.notifier)
                .dismiss(),
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
