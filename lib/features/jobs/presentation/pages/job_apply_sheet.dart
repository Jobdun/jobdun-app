import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/app/constants/app_strings.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../domain/entities/job.dart';
import 'job_detail_args.dart';

/// Bottom-sheet content for applying to a job. Extracted from
/// `job_detail_page.dart` to keep that file under the file-size budget.
class JobApplySheet extends StatefulWidget {
  const JobApplySheet({
    super.key,
    required this.args,
    required this.onSubmit,
    this.isApprenticeApplicant = false,
  });
  final JobDetailArgs args;
  final bool isApprenticeApplicant;

  /// Submits the application. Receives the parsed quote + trimmed cover note
  /// (null when blank) and awaits the caller's write so the button can show
  /// progress and stay disabled until the round-trip resolves. Returns an
  /// error string to render INSIDE the sheet (null = success) — a page-level
  /// SnackBar paints under the modal barrier, so a failed submit used to
  /// look like nothing happened (races audit, 2026-08-18).
  final Future<String?> Function(double? quote, String? coverNote) onSubmit;

  @override
  State<JobApplySheet> createState() => _JobApplySheetState();
}

class _JobApplySheetState extends State<JobApplySheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool get _profileApplication =>
      widget.args.isApprenticeship ||
      (widget.args.openToApprentices && widget.isApprenticeApplicant);

  final _rateCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

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
    if (_submitting || !(_formKey.currentState?.saveAndValidate() ?? false)) {
      return;
    }
    final rate = _profileApplication
        ? null
        : double.tryParse(_rateCtrl.text.trim());
    final note = _noteCtrl.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    String? error;
    try {
      error = await widget.onSubmit(rate, note.isEmpty ? null : note);
    } catch (_) {
      error = 'Application could not be sent. Please try again.';
    }
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: FormBuilder(
        key: _formKey,
        child: Padding(
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
                eyebrow: _profileApplication
                    ? 'APPLY FOR THIS JOB'
                    : AppStrings.respondSheetTitle,
                title: widget.args.title,
                size: PageHeaderSize.sub,
              ),
              Gap(20.h),
              if (_profileApplication)
                Text(
                  'The builder will see your profile and your resume if you have uploaded one. A resume is optional.',
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                )
              else ...[
                const FieldLabel('YOUR QUOTE'),
                Gap(AppSpacing.sm.h),
                Container(
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(AppRadius.input.r),
                    border: Border.all(color: c.border),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 2.h,
                  ),
                  child: Row(
                    children: [
                      Text(
                        '\$',
                        style: tt.headlineSmall!.copyWith(color: c.text3),
                      ),
                      Gap(4.w),
                      Expanded(
                        child: FormBuilderTextField(
                          name: 'quote',
                          controller: _rateCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: tt.headlineSmall!.copyWith(color: c.actionInk),
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
                      Text(
                        widget.args.pricingUnit.suffix.isEmpty
                            ? 'total'
                            : widget.args.pricingUnit.suffix,
                        style: tt.bodyMedium!.copyWith(color: c.text3),
                      ),
                    ],
                  ),
                ),
              ],
              Gap(AppSpacing.md.h),
              const FieldLabel('COVER NOTE (OPTIONAL)'),
              Gap(AppSpacing.sm.h),
              FormBuilderTextField(
                name: 'coverNote',
                controller: _noteCtrl,
                maxLines: 3,
                style: tt.bodyMedium!.copyWith(color: c.text1),
                decoration: const InputDecoration(
                  hintText: "Tell the builder why you're the right fit…",
                ),
              ),
              if (_error != null) ...[
                Gap(AppSpacing.sm.h),
                Text(_error!, style: tt.bodyMedium!.copyWith(color: c.urgent)),
              ],
              Gap(20.h),
              JButton(
                label: _submitting
                    ? AppStrings.respondSubmitting
                    : _profileApplication
                    ? 'SEND APPLICATION'
                    : AppStrings.respondSubmit,
                isLoading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
