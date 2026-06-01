import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/page_header.dart';
import 'job_detail_args.dart';

/// Bottom-sheet content for applying to a job. Extracted from
/// `job_detail_page.dart` to keep that file under the file-size budget.
class JobApplySheet extends StatefulWidget {
  const JobApplySheet({super.key, required this.args, required this.onSubmit});
  final JobDetailArgs args;

  /// Submits the application. Receives the parsed rate + trimmed cover note
  /// (null when blank) and awaits the caller's write so the button can show
  /// progress and stay disabled until the round-trip resolves.
  final Future<void> Function(double? proposedRate, String? coverNote) onSubmit;

  @override
  State<JobApplySheet> createState() => _JobApplySheetState();
}

class _JobApplySheetState extends State<JobApplySheet> {
  final _rateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _rateCtrl.text = widget.args.rate.replaceAll(RegExp(r'[^\d.]'), '');
  }

  @override
  void dispose() {
    _rateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rate = double.tryParse(_rateCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    setState(() => _submitting = true);
    await widget.onSubmit(rate, note.isEmpty ? null : note);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        AppSpacing.lg.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            eyebrow: 'APPLY FOR THIS JOB',
            title: widget.args.title,
            size: PageHeaderSize.sub,
          ),
          Gap(20.h),
          const FieldLabel('YOUR RATE'),
          Gap(AppSpacing.sm.h),
          Container(
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              border: Border.all(color: c.border),
            ),
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 2.h),
            child: Row(
              children: [
                Text('\$', style: tt.headlineSmall!.copyWith(color: c.text3)),
                Gap(4.w),
                Expanded(
                  child: TextField(
                    controller: _rateCtrl,
                    keyboardType: TextInputType.number,
                    style: tt.headlineSmall!.copyWith(color: c.action),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                      hintText: '85',
                    ),
                  ),
                ),
                Text('/hr', style: tt.bodyMedium!.copyWith(color: c.text3)),
              ],
            ),
          ),
          Gap(AppSpacing.md.h),
          const FieldLabel('COVER NOTE (OPTIONAL)'),
          Gap(AppSpacing.sm.h),
          // design-system-ok: TextEditingController not FormBuilder; theme draws chrome.
          TextField(
            controller: _noteCtrl,
            maxLines: 3,
            style: tt.bodyMedium!.copyWith(color: c.text1),
            decoration: const InputDecoration(
              hintText: "Tell the builder why you're the right fit…",
            ),
          ),
          Gap(20.h),
          JButton(
            label: _submitting ? 'SUBMITTING…' : 'SUBMIT APPLICATION',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
