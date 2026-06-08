import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/theme/theme_provider.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/widgets/logout_confirm_sheet.dart';

/// Account settings — appearance, account, legal, (dev tools,) and sign out.
///
/// (S6) Lifted off `/profile` onto its own `/settings` route so the profile
/// page leads with credibility instead of account chrome. Reached via the gear
/// in the profile header; full-screen with its own back button, no bottom nav.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, AppSpacing.sm.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  const Expanded(
                    child: PageHeader(
                      title: 'Settings',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.xl.h),
                child: Column(
                  children: [
                    JCard(
                      title: 'APPEARANCE',
                      children: [
                        _ToggleRow(
                          icon: isDark ? AppIcons.moon : AppIcons.sun,
                          label: 'Dark mode',
                          value: isDark,
                          onChanged: (_) =>
                              ref.read(themeProvider.notifier).toggle(),
                        ),
                      ],
                    ),
                    Gap(12.h),
                    JCard(
                      title: 'ACCOUNT',
                      children: [
                        _ActionRow(icon: AppIcons.email, label: 'Change email'),
                        _ActionRow(
                          icon: AppIcons.lock,
                          label: 'Change password',
                        ),
                        _ActionRow(
                          icon: AppIcons.notification,
                          label: 'Notifications',
                        ),
                        _ActionRow(
                          icon: AppIcons.policy,
                          label: 'Privacy settings',
                        ),
                      ],
                    ),
                    Gap(12.h),
                    JCard(
                      title: 'LEGAL',
                      children: [
                        _ActionRow(
                          icon: AppIcons.document,
                          label: 'Terms of Service',
                          onTap: () => context.push('/legal/terms'),
                        ),
                        _ActionRow(
                          icon: AppIcons.shield,
                          label: 'Privacy Policy',
                          onTap: () => context.push('/legal/privacy'),
                        ),
                      ],
                    ),
                    // Dev-only quick-links to the preview/showcase screens.
                    // Stripped from release builds by the kDebugMode gate.
                    if (kDebugMode) ...[
                      Gap(12.h),
                      JCard(
                        title: 'DEVELOPER TOOLS',
                        children: [
                          _ActionRow(
                            icon: AppIcons.eyeOpen,
                            label: 'Home preview (fixed tokens)',
                            onTap: () => context.push('/home-preview'),
                          ),
                          _ActionRow(
                            icon: AppIcons.gridView,
                            label: 'Design tokens',
                            onTap: () => context.push('/design-preview'),
                          ),
                          _ActionRow(
                            icon: AppIcons.image,
                            label: 'Logo animation',
                            onTap: () => context.push('/logo-animation'),
                          ),
                        ],
                      ),
                    ],
                    Gap(AppSpacing.lg.h),
                    JButton(
                      label: 'SIGN OUT',
                      variant: JButtonVariant.secondary,
                      onPressed: () => showLogoutSheet(context, ref),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: 14.h,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: c.text2),
            Gap(12.w),
            Expanded(
              child: Text(
                label,
                style: tt.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.text1,
                ),
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.inline.r,
              color: c.text3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 10.h,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md.r, color: c.text2),
          Gap(12.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyLarge!.copyWith(
                fontWeight: FontWeight.w500,
                color: c.text1,
              ),
            ),
          ),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
