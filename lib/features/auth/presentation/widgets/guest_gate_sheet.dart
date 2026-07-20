import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/providers/pending_return_provider.dart';

/// Sign-in wall for account-based actions reached while browsing as a guest
/// (App Review 5.1.1(v): browsing stays free; applying/saving/messaging need
/// the account those features are based on). Stores [returnTo] so the router
/// sends the user straight back here after they authenticate.
class GuestGateSheet extends ConsumerWidget {
  const GuestGateSheet({super.key, required this.actionCaps, this.returnTo});

  /// The gated action, ALL CAPS, completing "CREATE A FREE ACCOUNT TO …" —
  /// e.g. 'APPLY', 'SAVE JOBS', 'SEE BUILDER PROFILES'.
  final String actionCaps;

  /// Location to return to after auth (e.g. `/jobs/123`). Null = land home.
  final String? returnTo;

  static Future<void> show(
    BuildContext context, {
    required String actionCaps,
    String? returnTo,
  }) {
    return showJSheet<void>(
      context: context,
      builder: (_) =>
          GuestGateSheet(actionCaps: actionCaps, returnTo: returnTo),
    );
  }

  void _go(BuildContext context, WidgetRef ref, String location) {
    final target = returnTo;
    if (target != null) {
      ref.read(pendingReturnProvider.notifier).set(target);
    }
    Navigator.of(context).pop();
    context.go(location);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.card.r),
          ),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg.w,
          AppSpacing.xl.h,
          AppSpacing.lg.w,
          AppSpacing.xl.h,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'CREATE A FREE ACCOUNT TO $actionCaps',
              style: tt.headlineSmall!.copyWith(color: c.text1),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              'Takes under a minute. Browsing stays open without one.',
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
            Gap(AppSpacing.xl.h),
            JButton(
              label: 'CREATE ACCOUNT',
              onPressed: () => _go(context, ref, '/register'),
            ),
            Gap(AppSpacing.md.h),
            JButton(
              label: 'LOG IN',
              variant: JButtonVariant.secondary,
              onPressed: () => _go(context, ref, '/login'),
            ),
          ],
        ),
      ),
    );
  }
}
