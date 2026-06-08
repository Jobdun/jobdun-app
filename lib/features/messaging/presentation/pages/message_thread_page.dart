import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/conversation_typing.dart';
import '../providers/messaging_provider.dart';
import '../providers/messaging_realtime_provider.dart';
import '../state/thread_messages.dart';

part 'message_thread_widgets.dart';
part 'message_thread_status.dart';
part 'message_thread_actions.dart';

// Passed via GoRouter extra when pushing /messages/:conversationId
class ConversationArgs {
  const ConversationArgs({
    required this.conversationId,
    required this.otherName,
    this.jobTitle,
    this.otherInitials,
    this.otherUserId,
    this.otherAvatarUrl,
  });

  final String conversationId;
  final String otherName;
  final String? jobTitle;
  final String? otherInitials;
  // The counterparty's profile id — for presence (online) + typing self-filter.
  final String? otherUserId;
  // The counterparty's avatar photo (header + incoming bubbles).
  final String? otherAvatarUrl;
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

  // Per-conversation typing channel. Null when there's no signed-in user.
  ConversationTyping? _typing;
  bool _otherTyping = false; // is the counterparty typing right now?
  bool _typingSent = false; // have we broadcast our own "typing" already?
  Timer? _typingTimer; // fires "stop" after a keystroke pause

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

    // Join the realtime typing channel for live "typing…" both ways.
    final me = ref.read(currentUserIdSyncProvider);
    if (me != null) {
      _typing = ref
          .read(messagingRealtimeServiceProvider)
          .joinTyping(conversationId: _conversationId, myUserId: me);
      _typing!.otherIsTyping.listen((typing) {
        if (mounted) setState(() => _otherTyping = typing);
      });
      _textCtrl.addListener(_onTextChanged);
    }
  }

  // Broadcast "typing" once, then "stop" after a 2s keystroke pause.
  void _onTextChanged() {
    if (_textCtrl.text.trim().isEmpty) {
      _typingTimer?.cancel();
      if (_typingSent) {
        _typing?.setTyping(false);
        _typingSent = false;
      }
      return;
    }
    if (!_typingSent) {
      _typing?.setTyping(true);
      _typingSent = true;
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _typing?.setTyping(false);
      _typingSent = false;
    });
  }

  @override
  void dispose() {
    // Drop the per-thread realtime subscription; the controller keeps the
    // conversations stream alive for the inbox.
    _messaging.unsubscribeMessages(_conversationId);
    _typingTimer?.cancel();
    _textCtrl.removeListener(_onTextChanged);
    final disposeTyping = _typing?.dispose();
    if (disposeTyping != null) unawaited(disposeTyping);
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear(); // also fires _onTextChanged -> broadcasts "stop"
    await _messaging.sendMessage(conversationId: _conversationId, body: text);
    // The realtime echo re-renders the list; scroll handled by the listener.
  }

  // Long-press a bubble → Messenger-style action sheet (emoji react row +
  // Copy / Unsend). Edit lands in the next increment.
  Future<void> _showActions(ThreadEntry entry, bool isMine) async {
    HapticFeedback.mediumImpact();
    final result = await showJSheet<_SheetResult>(
      context: context,
      builder: (_) => _MessageActionsSheet(isMine: isMine),
    );
    if (!mounted || result == null) return;
    final id = entry.messageId;
    switch (result.action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: entry.body));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Copied'),
              duration: Duration(milliseconds: 900),
            ),
          );
        }
      case _MessageAction.unsend:
        if (id != null) {
          await _messaging.unsendMessage(
            conversationId: _conversationId,
            messageId: id,
          );
        }
      case _MessageAction.react:
        if (id != null && result.emoji != null) {
          await _messaging.toggleReaction(
            conversationId: _conversationId,
            messageId: id,
            emoji: result.emoji!,
          );
        }
    }
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
    final mState = ref.watch(messagingControllerProvider);
    final entries = mState.entriesFor(_conversationId, me);
    final loaded = mState.isThreadLoaded(_conversationId);
    final hasMore = mState.hasMoreFor(_conversationId);
    // Key of the last of my messages the counterparty has read — drives the
    // "Seen" mini-avatar (last write wins → the most recent seen message).
    String? lastSeenKey;
    for (final e in entries) {
      if (e.senderId == me && e.status == MessageStatus.seen) {
        lastSeenKey = e.key;
      }
    }
    final initials = args.otherInitials ?? _initials(args.otherName);
    final otherOnline =
        args.otherUserId != null &&
        ref
            .watch(onlineUserIdsProvider)
            .maybeWhen(
              data: (ids) => ids.contains(args.otherUserId),
              orElse: () => false,
            );

    // Keep the newest message in view as history loads and as realtime echoes
    // arrive (initial load, sent, received all change the count).
    ref.listen<int>(
      messagingControllerProvider.select(
        (s) =>
            s.messagesFor(_conversationId).length +
            s.outboxFor(_conversationId).length,
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
                  _HeaderAvatar(
                    initials: initials,
                    online: otherOnline,
                    imageUrl: args.otherAvatarUrl,
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
                        // Subtitle priority: typing → online → job title.
                        if (_otherTyping) ...[
                          Gap(2.h),
                          Text(
                            'typing…',
                            style: tt.bodySmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.action,
                            ),
                          ),
                        ] else if (otherOnline) ...[
                          Gap(2.h),
                          Text(
                            'Active now',
                            style: tt.bodySmall!.copyWith(
                              fontWeight: FontWeight.w600,
                              color: c.verified,
                            ),
                          ),
                        ] else if (args.jobTitle != null) ...[
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
              child: !loaded
                  ? const _ThreadSkeleton()
                  : entries.isEmpty
                  ? _ThreadEmpty(name: args.otherName)
                  : Column(
                      children: [
                        if (hasMore)
                          _LoadEarlierBar(
                            onTap: () => _messaging.loadOlder(_conversationId),
                          ),
                        Expanded(
                          child: ListView.builder(
                            controller: _scrollCtrl,
                            padding: EdgeInsets.symmetric(
                              horizontal: AppSpacing.md.w,
                              vertical: AppSpacing.md.h,
                            ),
                            itemCount: entries.length,
                            itemBuilder: (ctx, i) {
                              final entry = entries[i];
                              final isMine = entry.senderId == me;
                              final prev = i > 0 ? entries[i - 1] : null;
                              final next = i < entries.length - 1
                                  ? entries[i + 1]
                                  : null;
                              const groupGap = Duration(minutes: 15);
                              final newDay =
                                  prev == null ||
                                  !_sameDayLocal(
                                    prev.createdAt,
                                    entry.createdAt,
                                  );
                              final groupedWithPrev =
                                  prev != null &&
                                  !newDay &&
                                  prev.senderId == entry.senderId &&
                                  entry.createdAt.difference(prev.createdAt) <
                                      groupGap;
                              final lastInGroup =
                                  next == null ||
                                  next.senderId != entry.senderId ||
                                  !_sameDayLocal(
                                    next.createdAt,
                                    entry.createdAt,
                                  ) ||
                                  next.createdAt.difference(entry.createdAt) >=
                                      groupGap;
                              final bubble = _MessageBubble(
                                entry: entry,
                                isMine: isMine,
                                initials: initials,
                                imageUrl: args.otherAvatarUrl,
                                showAvatar: !isMine && lastInGroup,
                                groupedWithPrev: groupedWithPrev,
                                lastInGroup: lastInGroup,
                                showSeenAvatar: entry.key == lastSeenKey,
                                onRetry: entry.clientTag == null
                                    ? null
                                    : () => _messaging.retryMessage(
                                        conversationId: _conversationId,
                                        clientTag: entry.clientTag!,
                                      ),
                                // Hold a real (confirmed, non-deleted) bubble to
                                // open the actions sheet.
                                onLongPress: entry.isPending || entry.isDeleted
                                    ? null
                                    : () => _showActions(entry, isMine),
                              );
                              if (!newDay) return bubble;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _DaySeparator(date: entry.createdAt),
                                  bubble,
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),

            // Live typing indicator (animated dots) above the input bar.
            if (_otherTyping)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.md.w,
                  0,
                  0,
                  AppSpacing.sm.h,
                ),
                child: const Align(
                  alignment: Alignment.centerLeft,
                  child: _TypingBubble(),
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
                        // Text guardrail: hard cap input length; counter hidden
                        // to keep the chat bar clean.
                        maxLength: kMaxMessageLength,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => null,
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
                  // Active state: orange + white icon when there's text to
                  // send, dimmed + disabled when the field is empty.
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textCtrl,
                    builder: (context, value, _) {
                      final canSend = value.text.trim().isNotEmpty;
                      return GestureDetector(
                        key: const Key('thread-send'),
                        onTap: canSend ? _send : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 42.r,
                          height: 42.r,
                          decoration: BoxDecoration(
                            color: canSend ? c.action : c.surfaceRaised,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            AppIcons.send,
                            size: AppIconSize.md.r,
                            color: canSend ? c.onAction : c.text3,
                          ),
                        ),
                      );
                    },
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
