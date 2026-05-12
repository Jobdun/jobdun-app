import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

// Non-dismissible sheet shown when an authenticated user has no role yet —
// typically SSO sign-ups, since their user_metadata doesn't carry a role.
// Email sign-ups already picked at /register step 1 so never see this.
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
  UserRole? _selected;

  Future<void> _submit() async {
    final role = _selected;
    if (role == null) return;
    final ok = await ref
        .read(authControllerProvider.notifier)
        .setRoleAndStubProfile(role);
    if (ok && mounted) Navigator.of(context).pop();
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
                'WHO ARE YOU?',
                style: tt.headlineMedium!.copyWith(
                  color: c.text1,
                  letterSpacing: 0.5,
                ),
              ),
              Gap(6.h),
              Text(
                'Pick your role to finish setting up.',
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),
              Gap(AppSpacing.lg.h),
              Row(
                children: [
                  Expanded(
                    child: _RoleCard(
                      icon: Iconsax.buildings,
                      label: 'BUILDER',
                      description: 'Post jobs, hire crews',
                      selected: _selected == UserRole.builder,
                      onTap: () => setState(() => _selected = UserRole.builder),
                      c: c,
                      tt: tt,
                    ),
                  ),
                  Gap(12.w),
                  Expanded(
                    child: _RoleCard(
                      icon: Iconsax.cpu_charge,
                      label: 'TRADES',
                      description: 'Find work, get paid',
                      selected: _selected == UserRole.trade,
                      onTap: () => setState(() => _selected = UserRole.trade),
                      c: c,
                      tt: tt,
                    ),
                  ),
                ],
              ),
              if (errorMessage != null) ...[
                Gap(AppSpacing.sm.h),
                Text(
                  errorMessage,
                  style: tt.bodySmall!.copyWith(color: c.urgent),
                ),
              ],
              Gap(AppSpacing.lg.h),
              AppButton(
                label: isLoading ? 'Saving...' : 'Continue',
                isLoading: isLoading,
                onPressed: (_selected == null || isLoading) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    required this.c,
    required this.tt,
  });

  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final JColors c;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 32.r, color: selected ? c.action : c.text3),
            Gap(AppSpacing.md.h),
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
              style: tt.bodySmall!.copyWith(color: c.text2, fontSize: 12.sp),
            ),
          ],
        ),
      ),
    );
  }
}
