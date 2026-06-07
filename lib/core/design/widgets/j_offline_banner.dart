import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../theme/app_icons.dart';
import '../colors.dart';

/// Reusable offline indicator (Phase 2 — docs/CACHING_ARCHITECTURE.md §4).
///
/// Shown at the top of any screen when the device is offline, signalling that
/// what's on screen is last-known **saved** data rather than a bug. Drive it
/// from `isOnlineProvider`, e.g. `if (!isOnline) const JOfflineBanner()`.
class JOfflineBanner extends StatelessWidget {
  const JOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.urgentBg,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Icon(
              AppIcons.wifiOff,
              size: AppIconSize.micro.r,
              color: c.urgentTx,
            ),
            Gap(8.w),
            Text(
              "You're offline — showing saved data",
              style: tt.bodySmall!.copyWith(
                color: c.urgentTx,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
