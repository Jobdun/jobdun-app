import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/messaging_provider.dart';
import 'message_thread_page.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
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
    final userId = SupabaseConfig.isInitialized
        ? SupabaseConfig.client.auth.currentUser?.id ?? ''
        : '';

    final useReal = msgState.conversations.isNotEmpty;
    final totalUnread = useReal ? msgState.totalUnread : 3;

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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'INBOX',
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.12 * 11,
                            color: c.text3,
                          ),
                        ),
                        Gap(4.h),
                        ShaderMask(
                          shaderCallback: (bounds) =>
                              AppGradients.brandFlame.createShader(bounds),
                          child: Text(
                            'Messages',
                            style: tt.headlineSmall!.copyWith(
                              fontSize: 28.sp,
                              letterSpacing: 0.02 * 28,
                              color: Colors.white, // intentional: ShaderMask requires white for gradient
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (totalUnread > 0)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: c.action,
                        borderRadius: BorderRadius.circular(AppRadius.chip.r),
                      ),
                      child: Text(
                        '$totalUnread unread',
                        style: tt.bodySmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white, // intentional: white-on-action
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (msgState.isLoading)
              LinearProgressIndicator(
                color: c.action,
                backgroundColor: c.surface,
                minHeight: 2,
              ),
            Divider(height: 1, color: c.border),
            // ── Conversation list
            Expanded(
              child: (!useReal && _mockConvos.isEmpty)
                  ? _EmptyState(isBuilder: isBuilder)
                  : useReal
                      ? ListView.separated(
                          itemCount: msgState.conversations.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                          itemBuilder: (ctx, i) {
                            final conv = msgState.conversations[i];
                            final unread = conv.unreadCountFor(userId);
                            return _ConvoRow(
                              initials: _initials(conv.otherUserDisplayName ?? '?'),
                              name: conv.otherUserDisplayName ?? 'Unknown',
                              preview: conv.lastMessagePreview ?? '',
                              time: conv.lastMessageAt != null
                                  ? _relTime(conv.lastMessageAt!)
                                  : '',
                              unreadCount: unread,
                              jobTitle: conv.jobTitle,
                              onTap: () => context.push(
                                '/messages/${conv.id}',
                                extra: ConversationArgs(
                                  conversationId: conv.id,
                                  otherName: conv.otherUserDisplayName ?? 'Unknown',
                                  jobTitle: conv.jobTitle,
                                  otherInitials: _initials(conv.otherUserDisplayName ?? '?'),
                                ),
                              ),
                            );
                          },
                        )
                      : ListView.separated(
                          itemCount: _mockConvos.length,
                          separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                          itemBuilder: (ctx, i) {
                            final m = _mockConvos[i];
                            return _ConvoRow(
                              initials: m.initials,
                              name: m.name,
                              preview: m.preview,
                              time: m.time,
                              unreadCount: m.unread,
                              jobTitle: m.jobTitle,
                              onTap: () => context.push(
                                '/messages/mock-${m.initials}',
                                extra: ConversationArgs(
                                  conversationId: 'mock-${m.initials}',
                                  otherName: m.name,
                                  jobTitle: m.jobTitle,
                                  otherInitials: m.initials,
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
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

// ── Conversation Row ───────────────────────────────────────────────────────────

class _ConvoRow extends StatelessWidget {
  const _ConvoRow({
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unreadCount,
    required this.onTap,
    this.jobTitle,
  });

  final String initials;
  final String name;
  final String preview;
  final String time;
  final int unreadCount;
  final String? jobTitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final hasUnread = unreadCount > 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar
            Container(
              width: 46.r,
              height: 46.r,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: tt.headlineSmall!.copyWith(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w700,
                  color: c.action,
                ),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: tt.titleMedium!.copyWith(
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                            color: c.text1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Gap(8.w),
                      Text(
                        time,
                        style: tt.bodySmall!.copyWith(
                          fontWeight: FontWeight.w400,
                          color: hasUnread ? c.action : c.text3,
                        ),
                      ),
                    ],
                  ),
                  if (jobTitle != null) ...[
                    Gap(2.h),
                    Text(
                      jobTitle!,
                      style: tt.bodySmall!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.action,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  Gap(3.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: tt.bodyMedium!.copyWith(
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                            color: hasUnread ? c.text1 : c.text3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        Gap(8.w),
                        Container(
                          width: 20.r,
                          height: 20.r,
                          decoration: BoxDecoration(
                            color: c.action,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: tt.labelSmall!.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Colors.white, // intentional: white-on-action
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            Icon(Iconsax.message, size: 48.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              'NO MESSAGES YET.',
              style: tt.headlineSmall!.copyWith(
                fontSize: 22.sp,
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
          ],
        ),
      ),
    );
  }
}

// ── Sample mock data ───────────────────────────────────────────────────────────

class _MockConvo {
  const _MockConvo({
    required this.initials,
    required this.name,
    required this.preview,
    required this.time,
    required this.unread,
    this.jobTitle,
  });

  final String initials;
  final String name;
  final String preview;
  final String time;
  final int unread;
  final String? jobTitle;
}

const _mockConvos = [
  _MockConvo(
    initials: 'PC',
    name: 'Pinnacle Construct',
    preview: 'Thanks for applying! Can you start Monday at 7am?',
    time: '2h',
    unread: 2,
    jobTitle: 'Install 3-phase switchboard',
  ),
  _MockConvo(
    initials: 'BR',
    name: 'BuildRight Pty Ltd',
    preview: "We've shortlisted you for the framing job. Documents received.",
    time: '1d',
    unread: 0,
    jobTitle: 'Frame internal walls',
  ),
  _MockConvo(
    initials: 'CC',
    name: 'Coast & Country Builds',
    preview: 'Can you confirm your daily rate for the footings work?',
    time: '2d',
    unread: 1,
    jobTitle: 'Concrete footings — deck extension',
  ),
  _MockConvo(
    initials: 'HH',
    name: 'Harbour Homes',
    preview: 'Job has been completed. Review has been submitted. Thanks!',
    time: '5d',
    unread: 0,
    jobTitle: null,
  ),
];
