import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/verifications_provider.dart';

/// Persistent dismissible banner that nudges the user toward the wizard.
/// Self-hides when:
///   - the user is fully verified for their role (permanent — survives app
///     restarts; the live verification state is what's checked on every
///     build, no "I was verified once" flag)
///   - the user has tapped × this session
///   - no role is assigned yet (defensive — never render the wrong copy)
///
/// Role is derived from `authControllerProvider.role` so the banner always
/// renders the right copy + uses the right summariser. The Jobs page used
/// to hard-pass `NudgeRole.trade` regardless of the signed-in user — which
/// meant verified builders kept seeing tradie copy AND the banner refused
/// to hide because `summariseForTrade` looked for a licence row they don't
/// have. Removing the parameter fixed both behaviors at once.
class VerificationNudgeBanner extends ConsumerWidget {
  const VerificationNudgeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authControllerProvider.select((s) => s.role));
    if (role == null) return const SizedBox.shrink();

    final dismissed = ref.watch(verificationBannerDismissedProvider);
    if (dismissed) return const SizedBox.shrink();

    final async = ref.watch(myVerificationsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (rows) {
        final summary = role == UserRole.trade
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

class _Banner extends ConsumerWidget {
  const _Banner({required this.role});
  final UserRole role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    // Trade copy avoids the "about a minute" auto-path promise — for trades
    // we now route straight to manual upload + a person reviews within ~24 h.
    final copy = role == UserRole.trade
        ? 'Verified workers get hired faster. Upload takes a minute.'
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
