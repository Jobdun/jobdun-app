import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/navigation/notification_routes.dart';
import '../../domain/entities/app_notification.dart';
import '../providers/notifications_provider.dart';
import '../widgets/notification_section_header.dart';
import '../widgets/notification_tile.dart';
import '../widgets/notifications_empty_state.dart';

/// Live notifications feed — realtime-synced via `NotificationsController`.
/// Grouped NEW (unread, orange strip) then EARLIER; row tap marks read and
/// deep-links via [resolveNotificationRoute].
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('NOTIFICATIONS'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: () => ref
                  .read(notificationsControllerProvider.notifier)
                  .markAllRead(),
              child: Text(
                'MARK ALL READ',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge!.copyWith(color: c.actionInk),
              ),
            ),
        ],
      ),
      body: SafeArea(child: _Body(state: state)),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.state});

  final NotificationsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const _NotificationsSkeleton();
    }
    if (state.error != null && state.notifications.isEmpty) {
      return _ErrorRetry(message: state.error!);
    }
    if (state.notifications.isEmpty) {
      return const NotificationsEmptyState();
    }

    final rows = _buildRows(context, ref, state.notifications);
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(notificationsControllerProvider.notifier).load(),
      child: JStaggeredList(
        itemCount: rows.length,
        padding: EdgeInsets.only(bottom: AppSpacing.xl.h),
        physics: const AlwaysScrollableScrollPhysics(),
        itemBuilder: (context, index) => rows[index],
      ),
    );
  }

  List<Widget> _buildRows(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
  ) {
    final unread = notifications.where((n) => !n.isRead).toList();
    final read = notifications.where((n) => n.isRead).toList();

    Widget tile(AppNotification n) =>
        NotificationTile(notification: n, onTap: () => _open(context, ref, n));

    return [
      if (unread.isNotEmpty) ...[
        const NotificationSectionHeader(label: 'NEW'),
        ...unread.map(tile),
      ],
      if (read.isNotEmpty) ...[
        const NotificationSectionHeader(label: 'EARLIER'),
        ...read.map(tile),
      ],
    ];
  }

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    if (!n.isRead) {
      ref.read(notificationsControllerProvider.notifier).markRead(n.id);
    }
    final route = resolveNotificationRoute(type: n.type, data: n.data);
    if (route != '/notifications') context.push(route);
  }
}

class _NotificationsSkeleton extends StatelessWidget {
  const _NotificationsSkeleton();

  @override
  Widget build(BuildContext context) {
    final placeholder = AppNotification(
      id: 'skeleton',
      userId: '',
      type: 'new_job',
      title: 'New job near you',
      body: 'A new job matching your trade was just posted nearby.',
      createdAt: DateTime.now(),
    );
    return JSkeletonList(
      enabled: true,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        itemBuilder: (context, index) =>
            NotificationTile(notification: placeholder, onTap: () {}),
      ),
    );
  }
}

class _ErrorRetry extends ConsumerWidget {
  const _ErrorRetry({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'COULDN\'T LOAD NOTIFICATIONS',
              style: tt.headlineSmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.sm.h),
            Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: tt.bodyMedium!.copyWith(color: c.text2),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.xl.h),
            JButton(
              label: 'RETRY',
              onPressed: () =>
                  ref.read(notificationsControllerProvider.notifier).load(),
            ),
          ],
        ),
      ),
    );
  }
}
