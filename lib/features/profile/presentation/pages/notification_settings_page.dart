import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../providers/notification_prefs_provider.dart';

/// Per-category push-notification preferences, reached from
/// `/settings → Notifications`. One [JSwitch] row per category; a flip writes
/// straight through to `notification_preferences` (default-on: a missing row
/// means enabled). The central push trigger reads `push_enabled` to gate push,
/// so muting a category here suppresses its push while keeping the in-app row.
class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  // Display order + labels + glyphs for each category. Keys match
  // NotificationPrefsRemoteDataSource.categories exactly.
  static const _rows = <({String category, String label, IconData icon})>[
    (category: 'jobs', label: 'Jobs', icon: AppIcons.briefcase),
    (category: 'applications', label: 'Applications', icon: AppIcons.document),
    (category: 'messages', label: 'Messages', icon: AppIcons.chat),
    (category: 'reviews', label: 'Reviews', icon: AppIcons.star),
    (category: 'verification', label: 'Verification', icon: AppIcons.verified),
    (
      category: 'announcements',
      label: 'Announcements',
      icon: AppIcons.notification,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final prefs = ref.watch(notificationPrefsControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar (mirrors SettingsPage)
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
                      title: 'Notifications',
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose which push notifications you want to receive. '
                      'Turning one off still keeps it in your in-app activity.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.copyWith(color: c.text2),
                    ),
                    Gap(AppSpacing.lg.h),
                    // Loading → skeleton; error → tappable retry; data → toggles.
                    switch (prefs) {
                      AsyncData(:final value) => _PushPrefsCard(prefs: value),
                      AsyncError() => _PrefsErrorCard(
                        onRetry: () => ref
                            .read(notificationPrefsControllerProvider.notifier)
                            .refresh(),
                      ),
                      _ => JSkeletonList(
                        enabled: true,
                        child: _PushPrefsCard(prefs: _skeletonPrefs),
                      ),
                    },
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Placeholder data for the skeleton — all-on so the shimmer masks a
  // full-height card matching the loaded layout. Derived from [_rows] so the
  // page never reaches across the presentation→data boundary for the category
  // list.
  static final Map<String, bool> _skeletonPrefs = {
    for (final row in _rows) row.category: true,
  };
}

class _PushPrefsCard extends ConsumerWidget {
  const _PushPrefsCard({required this.prefs});

  final Map<String, bool> prefs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return JCard(
      title: 'PUSH NOTIFICATIONS',
      children: [
        for (final row in NotificationSettingsPage._rows)
          _ToggleRow(
            icon: row.icon,
            label: row.label,
            value: prefs[row.category] ?? true,
            onChanged: (next) => ref
                .read(notificationPrefsControllerProvider.notifier)
                .setPushEnabled(row.category, next),
          ),
      ],
    );
  }
}

class _PrefsErrorCard extends StatelessWidget {
  const _PrefsErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onRetry,
      child: JCard(
        title: 'PUSH NOTIFICATIONS',
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: 14.h,
            ),
            child: Row(
              children: [
                Icon(AppIcons.warning, size: AppIconSize.md.r, color: c.text2),
                Gap(12.w),
                Expanded(
                  child: Text(
                    "Couldn't load your preferences. Tap to retry.",
                    style: tt.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w500,
                      color: c.text1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
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
