import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

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

  bool get isMock => conversationId.startsWith('mock-');
}

class _Msg {
  const _Msg({required this.text, required this.isMine, required this.time});
  final String text;
  final bool isMine;
  final String time;
}

const _mockThread = [
  _Msg(
    text: "Hi, I saw your job posting and I'm interested in the role.",
    isMine: false,
    time: '10:22 AM',
  ),
  _Msg(
    text: 'Thanks for reaching out! Do you have your current licence handy?',
    isMine: true,
    time: '10:25 AM',
  ),
  _Msg(
    text: 'Yes — EL 123456 NSW, valid until Dec 2026. Happy to send a copy.',
    isMine: false,
    time: '10:28 AM',
  ),
  _Msg(
    text: 'Great. Can you start Monday at 7am? Site is in Surry Hills.',
    isMine: true,
    time: '10:31 AM',
  ),
  _Msg(
    text: "Absolutely, I'll be there. What's the site address?",
    isMine: false,
    time: '10:34 AM',
  ),
];

class MessageThreadPage extends StatefulWidget {
  const MessageThreadPage({super.key, required this.args});

  final ConversationArgs args;

  @override
  State<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends State<MessageThreadPage> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _localMessages = <_Msg>[];

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final now = TimeOfDay.now();
    final h = now.hourOfPeriod == 0 ? 12 : now.hourOfPeriod;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.period == DayPeriod.am ? 'AM' : 'PM';
    setState(() {
      _localMessages.add(_Msg(text: text, isMine: true, time: '$h:$m $period'));
      _textCtrl.clear();
    });
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
    final initials = args.otherInitials ?? _initials(args.otherName);
    final allMessages = [..._mockThread, ..._localMessages];

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
                  // Avatar
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
              child: ListView.builder(
                controller: _scrollCtrl,
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.md.h,
                ),
                itemCount: allMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = allMessages[i];
                  final isMine = msg.isMine;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: Row(
                      mainAxisAlignment: isMine
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMine) ...[
                          Container(
                            width: 28.r,
                            height: 28.r,
                            decoration: BoxDecoration(
                              color: c.surfaceRaised,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: tt.labelSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                                color: c.action,
                              ),
                            ),
                          ),
                          Gap(AppSpacing.sm.w),
                        ],
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMine
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 14.w,
                                  vertical: 10.h,
                                ),
                                decoration: BoxDecoration(
                                  color: isMine ? c.action : c.card,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16.r),
                                    topRight: Radius.circular(16.r),
                                    bottomLeft: Radius.circular(
                                      isMine ? 16.r : 4.r,
                                    ),
                                    bottomRight: Radius.circular(
                                      isMine ? 4.r : 16.r,
                                    ),
                                  ),
                                  border: isMine
                                      ? null
                                      : Border.all(color: c.border),
                                ),
                                child: Text(
                                  msg.text,
                                  style: tt.bodyLarge!.copyWith(
                                    fontWeight: FontWeight.w400,
                                    color: isMine
                                        ? Colors
                                              .white // intentional
                                        : c.text1,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                              Gap(4.h),
                              Text(
                                msg.time,
                                style: tt.labelSmall!.copyWith(color: c.text3),
                              ),
                            ],
                          ),
                        ),
                        if (isMine) Gap(AppSpacing.sm.w),
                      ],
                    ),
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
