import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// Status Command Bar (heatmap pairing): the top of the screen is the
/// red/stretch zone, so this bar is built to be READ, not pressed — the
/// tradie's live availability state (the builder gets the wordmark) plus the
/// low-frequency bell. The avatar/account moved to the bottom dock where the
/// thumb lives. The pill IS tappable (→ /schedule) but that's a shortcut,
/// not a requirement — the dock's account sheet carries the same route.
class HomeStatusBar extends ConsumerWidget {
  const HomeStatusBar({super.key, required this.onNotificationsTap});

  final VoidCallback onNotificationsTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isTrade = ref.watch(
      authControllerProvider.select((s) => s.role == UserRole.trade),
    );
    final available = ref.watch(
      profileControllerProvider.select((s) => s.tradeProfile?.isAvailable),
    );

    return Row(
      children: [
        if (isTrade)
          _AvailabilityPill(
            available: available ?? true,
            onTap: () => context.go('/schedule'),
          )
        else
          Text(
            'JOBDUN',
            style: tt.titleLarge!.copyWith(letterSpacing: 3, color: c.text1),
          ),
        const Spacer(),
        Semantics(
          label: 'Notifications',
          button: true,
          child: IconButton(
            onPressed: onNotificationsTap,
            icon: Icon(
              AppIcons.notification,
              size: AppIconSize.nav.r,
              color: c.text2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Glanceable availability state — dual-encoded (dot colour + label text,
/// never colour alone). Tap jumps to the schedule calendar.
class _AvailabilityPill extends StatelessWidget {
  const _AvailabilityPill({required this.available, required this.onTap});

  final bool available;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (bg, fg, label) = available
        ? (c.verifiedBg, c.verifiedTx, 'AVAILABLE')
        : (c.surfaceRaised, c.text1, 'AWAY');
    return Semantics(
      label: available
          ? 'You are available for work. Opens schedule.'
          : 'You are marked away. Opens schedule.',
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.r,
                height: 8.r,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              ),
              Gap(6.w),
              Text(
                label,
                style: tt.labelMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: fg,
                ),
              ),
              Gap(4.w),
              Icon(AppIcons.chevronRight, size: AppIconSize.micro.r, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}
