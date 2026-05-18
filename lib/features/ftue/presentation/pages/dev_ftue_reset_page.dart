import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/services/ftue_service.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/ftue_gate_provider.dart';

// Debug-only surface (route /dev/reset-ftue, registered only in kDebugMode)
// so QA can re-enter the FTUE carousel without uninstalling.
class DevFtueResetPage extends ConsumerWidget {
  const DevFtueResetPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final gate = ref.watch(ftueGateProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: const Text('Dev · FTUE reset')),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Current state',
                style: tt.labelLarge!.copyWith(color: c.text3),
              ),
              Gap(AppSpacing.sm.h),
              Text(
                'hasCompletedFtue: ${gate.hasCompleted}',
                style: tt.bodyMedium!.copyWith(color: c.text1),
              ),
              Gap(AppSpacing.xl.h),
              AppButton(
                label: 'RESET FTUE',
                onPressed: () async {
                  await FtueService.resetFtue();
                  await ref.read(ftueGateProvider.notifier).reload();
                  if (context.mounted) context.go('/ftue');
                },
              ),
              Gap(AppSpacing.md.h),
              AppButton(
                label: 'GO TO /FTUE',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/ftue'),
              ),
              Gap(AppSpacing.md.h),
              AppButton(
                label: 'VIEW ICON GALLERY',
                variant: AppButtonVariant.secondary,
                onPressed: () => context.go('/dev/icons'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
