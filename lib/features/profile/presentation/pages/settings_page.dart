import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../app/theme/theme_provider.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_confirm_sheet.dart';
import '../../../auth/presentation/widgets/delete_account_sheet.dart';
import '../providers/profile_provider.dart';

/// Account settings — appearance, account, legal, (dev tools,) and sign out.
///
/// (S6) Lifted off `/profile` onto its own `/settings` route so the profile
/// page leads with credibility instead of account chrome. Reached via the gear
/// in the profile header; full-screen with its own back button, no bottom nav.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  /// Change password = the shipped reset-email flow (2026-07-31) pointed at
  /// the signed-in address. Replaces a dead row (K11, 2026-08-18 audit).
  Future<void> _sendPasswordReset(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authControllerProvider.select((s) => s.email));
    final messenger = ScaffoldMessenger.of(context);
    if (email == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text("Couldn't find your account email.")),
      );
      return;
    }
    await ref.read(authControllerProvider.notifier).sendPasswordReset(email);
    final error = ref.read(authControllerProvider).errorMessage;
    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Password reset link sent to $email.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar (Figma node 134:9567). The mock's title reads
            // "Setting"; the app has always said "Settings" and that is the
            // correct plural, so the typo is not carried over.
            Padding(
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 16.w, 8.h),
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
                  Expanded(
                    child: Text(
                      'Settings',
                      style: Theme.of(context).textTheme.headlineSmall!
                          .copyWith(fontSize: 24, height: 1.2, color: c.text1),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                // Figma node 134:9155 — 16dp page padding, 16dp between cards.
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, AppSpacing.xl.h),
                child: Column(
                  children: [
                    _SettingsCard(
                      title: 'Appearance',
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
                    Gap(16.h),
                    _SettingsCard(
                      title: 'Account',
                      children: [
                        // (K11, 2026-08-18 audit) 'Change email' and 'Privacy
                        // settings' rows are gone — they drew chevrons with
                        // no handler. Change password reuses the shipped
                        // reset-email flow.
                        //
                        // The mock draws a phone glyph on this row; a padlock
                        // is what the row actually does, so the icon stays.
                        _ActionRow(
                          icon: AppIcons.lock,
                          label: 'Change password',
                          onTap: () => _sendPasswordReset(context, ref),
                        ),
                        _ActionRow(
                          icon: AppIcons.notification,
                          label: 'Notifications',
                          onTap: () => context.push('/settings/notifications'),
                        ),
                        _ActionRow(
                          icon: AppIcons.calendar,
                          label: 'Schedule',
                          // push (not go): SchedulePage pops back here. The
                          // old go() left it stackless AND the duplicate
                          // shell route shadowed the real bookings page.
                          onTap: () => context.push('/schedule'),
                        ),
                        // Not in the mock, which shows a builder — these only
                        // render for a trade profile, so the builder's card
                        // matches the drawn three rows exactly.
                        if (ref.watch(
                          profileControllerProvider.select(
                            (s) => s.tradeProfile != null,
                          ),
                        )) ...[
                          _ActionRow(
                            icon: AppIcons.calendar,
                            label: 'Availability calendar',
                            onTap: () => context.push('/settings/availability'),
                          ),
                          _ActionRow(
                            icon: AppIcons.document,
                            label: 'Quote requests',
                            onTap: () => context.push('/quotes'),
                          ),
                        ],
                      ],
                    ),
                    Gap(16.h),
                    _SettingsCard(
                      title: 'Legal',
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
                    Gap(16.h),
                    JButton(
                      label: 'Log out',
                      variant: JButtonVariant.outline,
                      onPressed: () => showLogoutSheet(context, ref),
                    ),
                    Gap(16.h),
                    // Play/Apple-required account deletion.
                    //
                    // ⚠️ This sat far from Log out on purpose — a prominent
                    // danger button beside a routine one invites accidental
                    // taps, and that nearly cost this account. The Figma frame
                    // (node 134:9547) puts them 16dp apart, and that placement
                    // was signed off on 2026-08-29 on the condition that
                    // `showDeleteAccountSheet` keeps gating it: a mis-tap
                    // opens a confirm sheet, never a deletion. Do not make
                    // this button destructive-on-tap.
                    JButton(
                      label: 'Delete my account',
                      variant: JButtonVariant.dangerOutline,
                      onPressed: () => showDeleteAccountSheet(context, ref),
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

/// Grouped settings card from the Figma Setting frame (node 134:9189): a 16dp
/// bold title over its rows, 24dp beneath the title and between rows.
class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium!.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.0,
              color: c.text1,
            ),
          ),
          for (final child in children) ...[Gap(24.h), child],
        ],
      ),
    );
  }
}

/// Tappable settings row — 18dp glyph, label, trailing chevron
/// (Figma node 134:9304). The card supplies the vertical rhythm, so the row
/// pads only enough to clear the 44dp touch floor.
class _ActionRow extends StatelessWidget {
  // onTap is required: the old `onTap ?? () {}` default let rows ship with a
  // chevron and no behavior (K11, 2026-08-18 audit).
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: 26.h),
          child: Row(
            children: [
              Icon(icon, size: 18.r, color: c.text1),
              Gap(8.w),
              Expanded(
                child: Text(
                  label,
                  style: tt.bodyLarge!.copyWith(height: 1.0, color: c.text1),
                ),
              ),
              Icon(AppIcons.chevronRight, size: 18.r, color: c.text2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Settings row carrying a switch instead of a chevron (Figma node 134:9192).
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

    return Row(
      children: [
        Icon(icon, size: 18.r, color: c.text1),
        Gap(8.w),
        Expanded(
          child: Text(
            label,
            style: tt.bodyLarge!.copyWith(height: 1.0, color: c.text1),
          ),
        ),
        JSwitch(value: value, onChanged: onChanged),
      ],
    );
  }
}
