import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../providers/auth_provider.dart';

// Non-dismissible sheet shown when an authenticated user has no role yet —
// typically SSO sign-ups, since their user_metadata doesn't carry a role.
// Email sign-ups already picked at /register so never see this.
//
// Tap-to-confirm: a single card tap saves the role and dismisses. No
// Continue button — matches the /register step-1 tap-to-advance behaviour.
class RoleSelectionSheet extends ConsumerStatefulWidget {
  const RoleSelectionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const RoleSelectionSheet(),
    );
  }

  @override
  ConsumerState<RoleSelectionSheet> createState() => _RoleSelectionSheetState();
}

class _RoleSelectionSheetState extends ConsumerState<RoleSelectionSheet> {
  UserRole? _pending;

  Future<void> _pickAndConfirm(UserRole role) async {
    // Optimistic highlight so the user sees their choice register before the
    // network roundtrip finishes.
    setState(() => _pending = role);
    final ok = await ref
        .read(authControllerProvider.notifier)
        .setRoleAndStubProfile(role);
    if (!ok && mounted) {
      setState(() => _pending = null);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final isLoading = ref.watch(
      authControllerProvider.select((s) => s.isLoading),
    );
    final errorMessage = ref.watch(
      authControllerProvider.select((s) => s.errorMessage),
    );

    return PopScope(
      canPop: false,
      child: SafeArea(
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
            AppSpacing.lg.h,
            AppSpacing.lg.w,
            AppSpacing.xl.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                alignment: Alignment.center,
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: c.border,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Gap(AppSpacing.lg.h),
              Text(
                'ONE LAST THING',
                style: tt.headlineMedium!.copyWith(
                  color: c.text1,
                  letterSpacing: 0.5,
                ),
              ),
              Gap(6.h),
              Text(
                'Which side are you on?',
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),
              Gap(AppSpacing.lg.h),
              _SheetRoleCard(
                icon: AppIcons.builder,
                label: "I'M HIRING",
                description: 'Post jobs, review applications, manage crews.',
                pending: _pending == UserRole.builder,
                disabled: isLoading,
                onTap: () => _pickAndConfirm(UserRole.builder),
                c: c,
                tt: tt,
              ),
              Gap(12.h),
              _SheetRoleCard(
                icon: AppIcons.findJobs.outline,
                label: "I'M LOOKING FOR WORK",
                description: 'Browse jobs, apply, get hired.',
                pending: _pending == UserRole.trade,
                disabled: isLoading,
                onTap: () => _pickAndConfirm(UserRole.trade),
                c: c,
                tt: tt,
              ),
              if (errorMessage != null) ...[
                Gap(AppSpacing.sm.h),
                Text(
                  errorMessage,
                  style: tt.bodySmall!.copyWith(color: c.urgent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRoleCard extends StatelessWidget {
  const _SheetRoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.pending,
    required this.disabled,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool pending;
  final bool disabled;
  final VoidCallback onTap;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: disabled ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(AppSpacing.lg.r),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(
              color: pending ? c.action : c.border,
              width: pending ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                decoration: BoxDecoration(
                  color: pending ? c.action : c.surfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.avatar.r),
                ),
                child: pending
                    ? SizedBox.square(
                        dimension: 18.r,
                        child: Padding(
                          padding: EdgeInsets.all(6.r),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white, // intentional: white-on-action
                          ),
                        ),
                      )
                    : Icon(icon, size: AppIconSize.md.r, color: c.text2),
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: tt.labelLarge!.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      description,
                      style: tt.bodySmall!.copyWith(
                        color: c.text2,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(AppSpacing.sm.w),
              Icon(
                AppIcons.forward,
                size: AppIconSize.md.r,
                color: pending ? c.action : c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
