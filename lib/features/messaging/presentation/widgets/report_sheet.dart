import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/report_submission.dart';
import '../providers/inbox_safety_provider.dart';

/// Report sheet (Phase D safety): one reason from the locked taxonomy +
/// optional details ("Something else" requires them). Feeds the admin
/// console's moderation queue via the `reports` table.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.otherName,
    required this.reportedId,
    required this.conversationId,
    this.messageId,
  });

  final String otherName;
  final String reportedId;
  final String conversationId;
  final String? messageId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportReason? _selected;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final me = ref.read(currentUserIdSyncProvider);
    if (me == null || _selected == null) return;
    final ok = await ref
        .read(inboxSafetyControllerProvider.notifier)
        .reportUser(
          ReportSubmission(
            reporterId: me,
            reportedId: widget.reportedId,
            conversationId: widget.conversationId,
            messageId: widget.messageId,
            reason: _selected!,
            details: _details.text.trim().isEmpty ? null : _details.text.trim(),
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('REPORT SUBMITTED.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final safety = ref.watch(inboxSafetyControllerProvider);
    final showDetails = _selected == ReportReason.other;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 20.w,
          right: 20.w,
          top: 20.h,
          bottom: 16.h + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REPORT ${widget.otherName.toUpperCase()}',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(12.h),
            Text(
              'WHY ARE YOU REPORTING THIS?',
              style: tt.labelLarge!.copyWith(
                color: c.text2,
                letterSpacing: 0.6,
              ),
            ),
            Gap(8.h),
            for (final reason in ReportReason.values) ...[
              _ReasonRow(
                reason: reason,
                selected: _selected == reason,
                onTap: () => setState(() => _selected = reason),
              ),
              Gap(6.h),
            ],
            if (showDetails) ...[
              Gap(4.h),
              TextField(
                controller: _details,
                maxLength: 500,
                maxLines: 3,
                style: tt.bodyMedium!.copyWith(color: c.text1),
                decoration: InputDecoration(
                  hintText: 'Tell us what happened…',
                  hintStyle: tt.bodyMedium!.copyWith(color: c.text3),
                  filled: true,
                  fillColor: c.surface,
                  counterStyle: tt.labelSmall!.copyWith(color: c.text3),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: c.border),
                    borderRadius: BorderRadius.zero,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: c.action),
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
            ],
            if (safety.error != null) ...[
              Gap(8.h),
              Text(
                safety.error!,
                style: tt.bodySmall!.copyWith(color: c.urgent),
              ),
            ],
            Gap(14.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'SUBMIT REPORT',
                variant: JButtonVariant.danger,
                isLoading: safety.isLoading,
                onPressed: _selected == null || safety.isLoading
                    ? null
                    : _submit,
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'CANCEL',
                variant: JButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReasonRow extends StatelessWidget {
  const _ReasonRow({
    required this.reason,
    required this.selected,
    required this.onTap,
  });

  final ReportReason reason;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: c.surface,
          border: Border.all(color: selected ? c.action : c.border),
        ),
        child: Row(
          children: [
            Icon(
              selected ? AppIcons.radioOn : AppIcons.radioOff,
              size: AppIconSize.inline.r,
              color: selected ? c.action : c.text3,
            ),
            Gap(10.w),
            Expanded(
              child: Text(
                reason.label.toUpperCase(),
                style: tt.titleSmall!.copyWith(
                  color: c.text1,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
