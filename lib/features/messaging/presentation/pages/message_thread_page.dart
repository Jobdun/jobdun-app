import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/message.dart';
import '../providers/messaging_provider.dart';

part 'message_thread_widgets.dart';

// Passed via GoRouter extra when pushing /messages/:conversationId
class ConversationArgs {
  const ConversationArgs({
    required this.conversationId,
    required this.otherName,
    this.jobTitle,
    this.otherInitials,
  });

  final String conversationId;
  final String otherName;
  final String? jobTitle;
  final String? otherInitials;
}

class MessageThreadPage extends ConsumerStatefulWidget {
  const MessageThreadPage({super.key, required this.args});

  final ConversationArgs args;

  @override
  ConsumerState<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final MessagingController _messaging;

  String get _conversationId => widget.args.conversationId;

  @override
  void initState() {
    super.initState();
    // Capture the notifier once — `ref` must not be used in dispose() during
    // tree teardown, but the stored notifier reference stays valid.
    _messaging = ref.read(messagingControllerProvider.notifier);
    // Initial-load triggers belong off the first frame (see CLAUDE.md Riverpod
    // rules). loadMessages fetches history + opens the realtime subscription;
    // markConversationRead zeroes the viewer's unread counter server-side.
    Future.microtask(() {
      if (!mounted) return;
      _messaging.loadMessages(_conversationId);
      _messaging.markConversationRead(_conversationId);
    });
  }

  @override
  void dispose() {
    // Drop the per-thread realtime subscription; the controller keeps the
    // conversations stream alive for the inbox.
    _messaging.unsubscribeMessages(_conversationId);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await _messaging.sendMessage(conversationId: _conversationId, body: text);
    // The realtime echo re-renders the list; scroll handled by the listener.
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final args = widget.args;
    final me = ref.watch(currentUserIdSyncProvider);
    final messages = ref.watch(
      messagingControllerProvider.select((s) => s.messagesFor(_conversationId)),
    );
    final initials = args.otherInitials ?? _initials(args.otherName);

    // Keep the newest message in view as history loads and as realtime echoes
    // arrive (initial load, sent, received all change the count).
    ref.listen<int>(
      messagingControllerProvider.select(
        (s) => s.messagesFor(_conversationId).length,
      ),
      (_, _) => _scrollToBottom(),
    );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Thread header
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 16.w, 12.h),
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
                  Container(
                    width: 38.r,
                    height: 38.r,
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.border),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      initials,
                      style: tt.labelLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.action,
                      ),
                    ),
                  ),
                  Gap(10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          args.otherName,
                          style: tt.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (args.jobTitle != null) ...[
                          Gap(2.h),
                          Text(
                            args.jobTitle!,
                            style: tt.bodySmall!.copyWith(
                              fontWeight: FontWeight.w500,
                              color: c.action,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(AppIcons.more, size: AppIconSize.md.r, color: c.text3),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            // ── Messages
            Expanded(
              child: messages.isEmpty
                  ? _ThreadEmpty(name: args.otherName)
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.md.h,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (ctx, i) {
                        final msg = messages[i];
                        final isMine = msg.senderId == me;
                        final prev = i > 0 ? messages[i - 1] : null;
                        final next = i < messages.length - 1
                            ? messages[i + 1]
                            : null;
                        const groupGap = Duration(minutes: 15);
                        final newDay =
                            prev == null ||
                            !_sameDayLocal(prev.createdAt, msg.createdAt);
                        final groupedWithPrev =
                            prev != null &&
                            !newDay &&
                            prev.senderId == msg.senderId &&
                            msg.createdAt.difference(prev.createdAt) < groupGap;
                        final lastInGroup =
                            next == null ||
                            next.senderId != msg.senderId ||
                            !_sameDayLocal(next.createdAt, msg.createdAt) ||
                            next.createdAt.difference(msg.createdAt) >=
                                groupGap;
                        final bubble = _MessageBubble(
                          message: msg,
                          isMine: isMine,
                          initials: initials,
                          showAvatar: !isMine && lastInGroup,
                          groupedWithPrev: groupedWithPrev,
                          lastInGroup: lastInGroup,
                        );
                        if (!newDay) return bubble;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _DaySeparator(date: msg.createdAt),
                            bubble,
                          ],
                        );
                      },
                    ),
            ),

            // ── Input bar
            Container(
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w,
                10.h,
                AppSpacing.md.w,
                10.h,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(24.r),
                        border: Border.all(color: c.border),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: 4.h,
                      ),
                      child: TextField(
                        controller: _textCtrl,
                        style: tt.bodyLarge!.copyWith(color: c.text1),
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: 'Message…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  Gap(10.w),
                  GestureDetector(
                    key: const Key('thread-send'),
                    onTap: _send,
                    child: Container(
                      width: 42.r,
                      height: 42.r,
                      decoration: BoxDecoration(
                        color: c.action,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        AppIcons.send,
                        size: AppIconSize.md.r,
                        color: Colors.white, // intentional
                      ),
                    ),
                  ),
                ],
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
}
