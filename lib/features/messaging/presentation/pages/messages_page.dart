import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../domain/entities/conversation.dart';
import '../providers/messaging_provider.dart';
import '../widgets/block_confirmation_sheet.dart';
import '../widgets/conversation_row.dart';
import '../widgets/inbox_search_bar.dart';
import '../widgets/report_sheet.dart';
import 'message_thread_page.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  bool _searchVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(messagingControllerProvider.notifier).loadConversations();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final msgState = ref.watch(messagingControllerProvider);
    final authState = ref.watch(authControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final userId = ref.watch(currentUserIdSyncProvider) ?? '';

    final totalUnread = msgState.totalUnread;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
              child: Row(
                children: [
                  const Expanded(child: PageHeader(title: 'Messages')),
                  IconButton(
                    tooltip: 'Search messages',
                    onPressed: () {
                      setState(() => _searchVisible = !_searchVisible);
                      if (!_searchVisible) {
                        ref
                            .read(messagingControllerProvider.notifier)
                            .setSearchQuery('');
                      }
                    },
                    icon: Icon(
                      AppIcons.search,
                      size: AppIconSize.md.r,
                      color: _searchVisible ? c.action : c.text1,
                    ),
                  ),
                  if (totalUnread > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: c.action,
                        borderRadius: BorderRadius.circular(AppRadius.chip.r),
                      ),
                      child: Text(
                        '$totalUnread unread',
                        style: tt.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.onAction, // dark-on-orange — 6.37:1
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedSize(
              duration: AppMotion.fast,
              curve: Curves.easeOut,
              child: _searchVisible
                  ? InboxSearchBar(
                      onChanged: (q) => ref
                          .read(messagingControllerProvider.notifier)
                          .setSearchQuery(q),
                      onClear: () {
                        ref
                            .read(messagingControllerProvider.notifier)
                            .setSearchQuery('');
                        setState(() => _searchVisible = false);
                      },
                    )
                  : const SizedBox.shrink(),
            ),
            Divider(height: 1, color: c.border),
            // ── Conversation list
            Expanded(
              child: msgState.isLoading && msgState.conversations.isEmpty
                  ? JSkeletonList(
                      enabled: true,
                      child: ListView.separated(
                        itemCount: 6,
                        separatorBuilder: (_, _) =>
                            Divider(height: 1, color: c.border),
                        itemBuilder: (_, _) => ConversationRow(
                          initials: 'AB',
                          name: 'Loading conversation placeholder',
                          preview: 'Last message preview placeholder text here',
                          time: '1h',
                          unreadCount: 0,
                          jobTitle: 'Loading job title placeholder',
                          onTap: () {},
                        ),
                      ),
                    )
                  : msgState.conversations.isEmpty
                  ? _EmptyState(isBuilder: isBuilder)
                  : msgState.filteredConversations.isEmpty
                  ? Center(
                      child: Text(
                        'NO CONVERSATIONS MATCH.',
                        style: tt.bodyMedium!.copyWith(color: c.text3),
                      ),
                    )
                  : JStaggeredList(
                      itemCount: msgState.filteredConversations.length,
                      separatorBuilder: (_, _) =>
                          Divider(height: 1, color: c.border),
                      itemBuilder: (ctx, i) {
                        final conv = msgState.filteredConversations[i];
                        final unread = conv.unreadCountFor(userId);
                        final row = ConversationRow(
                          isPinned: conv.isPinnedFor(userId),
                          isMuted: conv.isMutedFor(userId),
                          isBlocked: conv.status == ConversationStatus.blocked,
                          initials: _initials(conv.otherUserDisplayName ?? '?'),
                          name: conv.otherUserDisplayName ?? 'Unknown',
                          preview: conv.lastMessagePreview ?? '',
                          time: conv.lastMessageAt != null
                              ? _relTime(conv.lastMessageAt!)
                              : '',
                          unreadCount: unread,
                          jobTitle: conv.jobTitle,
                          avatarUrl: conv.otherUserAvatarUrl,
                          onTap: () => context.push(
                            '/messages/${conv.id}',
                            extra: ConversationArgs(
                              conversationId: conv.id,
                              otherName: conv.otherUserDisplayName ?? 'Unknown',
                              jobTitle: conv.jobTitle,
                              otherInitials: _initials(
                                conv.otherUserDisplayName ?? '?',
                              ),
                              otherUserId: conv.builderId == userId
                                  ? conv.tradeId
                                  : conv.builderId,
                              otherAvatarUrl: conv.otherUserAvatarUrl,
                            ),
                          ),
                        );
                        final pinned = conv.isPinnedFor(userId);
                        final muted = conv.isMutedFor(userId);
                        return Slidable(
                          key: ValueKey('convo-${conv.id}'),
                          // Power tools on the left (D-11): pin + mark-unread.
                          startActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.44,
                            children: [
                              SlidableAction(
                                onPressed: (_) {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(
                                        messagingControllerProvider.notifier,
                                      )
                                      .pinConversation(conv.id, pin: !pinned);
                                },
                                backgroundColor: c.available,
                                foregroundColor: c.text1,
                                icon: pinned
                                    ? AppIcons.pinFilled
                                    : AppIcons.pin,
                                label: pinned ? 'UNPIN' : 'PIN',
                                autoClose: true,
                              ),
                              SlidableAction(
                                onPressed: (_) {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(
                                        messagingControllerProvider.notifier,
                                      )
                                      .markConversationUnread(conv.id);
                                },
                                backgroundColor: c.surfaceRaised,
                                foregroundColor: c.text1,
                                icon: AppIcons.email,
                                label: 'UNREAD',
                                autoClose: true,
                              ),
                            ],
                          ),
                          // Removal + safety on the right: mute, archive, block.
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.56,
                            children: [
                              SlidableAction(
                                onPressed: (_) {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(
                                        messagingControllerProvider.notifier,
                                      )
                                      .muteConversation(conv.id, mute: !muted);
                                },
                                backgroundColor: c.surfaceRaised,
                                foregroundColor: c.text1,
                                icon: muted
                                    ? AppIcons.muteFilled
                                    : AppIcons.mute,
                                label: muted ? 'UNMUTE' : 'MUTE',
                                autoClose: true,
                              ),
                              SlidableAction(
                                onPressed: (_) {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(
                                        messagingControllerProvider.notifier,
                                      )
                                      .archiveConversation(conv.id);
                                },
                                backgroundColor: c.surfaceRaised,
                                foregroundColor: c.text1,
                                icon: AppIcons.archive,
                                label: 'ARCHIVE',
                                autoClose: true,
                              ),
                              SlidableAction(
                                onPressed: (_) {
                                  HapticFeedback.lightImpact();
                                  _showBlockSheet(conv, userId);
                                },
                                backgroundColor: c.urgent,
                                foregroundColor: c.text1,
                                icon: AppIcons.block,
                                label: 'BLOCK',
                                autoClose: true,
                              ),
                            ],
                          ),
                          child: row,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBlockSheet(Conversation conv, String userId) {
    final otherName = conv.otherUserDisplayName ?? 'this person';
    final otherId = conv.builderId == userId ? conv.tradeId : conv.builderId;
    showJSheet<void>(
      context: context,
      backgroundColor: context.c.card,
      builder: (_) => BlockConfirmationSheet(
        otherName: otherName,
        blockedId: otherId,
        conversationId: conv.id,
        onAlsoReport: () => _showReportSheet(conv, userId),
      ),
    );
  }

  void _showReportSheet(Conversation conv, String userId) {
    final otherName = conv.otherUserDisplayName ?? 'this person';
    final otherId = conv.builderId == userId ? conv.tradeId : conv.builderId;
    showJSheet<void>(
      context: context,
      backgroundColor: context.c.card,
      builder: (_) => ReportSheet(
        otherName: otherName,
        reportedId: otherId,
        conversationId: conv.id,
      ),
    );
  }

  static String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  static String _relTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}

// ── Empty state ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isBuilder});

  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.chat, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              'NO MESSAGES YET.',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(AppSpacing.sm.h),
            Text(
              isBuilder
                  ? 'Hire a tradie to start a conversation.'
                  : 'Apply to jobs to start chatting with builders.',
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
            Gap(AppSpacing.lg.h),
            SizedBox(
              width: 200.w,
              child: JButton(
                label: isBuilder ? 'POST A JOB' : 'BROWSE JOBS',
                onPressed: () =>
                    context.go(isBuilder ? '/jobs/create' : '/jobs'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
