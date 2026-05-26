import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';

typedef OnLicenceDone =
    void Function({
      String? licenceNumber,
      String? state,
      String? tradeClass,
      VerifyResult? result,
    });

/// Wizard Step 2 (trade only): licence entry. Calls verify-licence and
/// surfaces the result for the result screen to render. A visible Skip
/// affordance lets the user finish with just ABN verified (v2 spec —
/// licence is optional even within the wizard).
class WizardLicenceStep extends ConsumerStatefulWidget {
  const WizardLicenceStep({
    super.key,
    required this.stepLabel,
    required this.onDone,
    required this.onSkip,
  });

  final String stepLabel;
  final OnLicenceDone onDone;
  final VoidCallback onSkip;

  @override
  ConsumerState<WizardLicenceStep> createState() => _WizardLicenceStepState();
}

class _WizardLicenceStepState extends ConsumerState<WizardLicenceStep> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _calling = false;
  String? _errorMessage;
  String _state = 'NSW';
  String _tradeClass = 'Electrician';
  VerifyResult? _pending;
  String? _pendingNumber;

  static const _states = ['NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'ACT', 'NT'];

  // Lightweight starter list — expand per regulator once real adapters land.
  static const _classes = [
    'Electrician',
    'Plumber',
    'Carpenter',
    'Painter',
    'Tiler',
    'Plasterer',
    'Refrigeration mechanic',
    'Gasfitter',
  ];

  Future<void> _onVerify() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final number =
        (_formKey.currentState!.value['licence_number'] as String? ?? '')
            .trim();
    if (number.isEmpty) {
      setState(() => _errorMessage = 'Enter your licence number.');
      return;
    }
    setState(() {
      _calling = true;
      _errorMessage = null;
    });
    final result = await ref
        .read(invokeVerifyLicenceUseCaseProvider)
        .call(licenceNumber: number, state: _state, tradeClass: _tradeClass);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _calling = false;
        _errorMessage = f.message;
      }),
      (r) {
        setState(() {
          _calling = false;
          // Stay on the step for non-verified outcomes so the user can
          // see the reason + reach the manual-upload fallback. Verified
          // outcomes hand straight off to the result screen.
          if (r is VerifyVerified) {
            widget.onDone(
              licenceNumber: number,
              state: _state,
              tradeClass: _tradeClass,
              result: r,
            );
          } else {
            _pending = r;
            _pendingNumber = number;
          }
        });
      },
    );
  }

  void _continueWithResult() {
    widget.onDone(
      licenceNumber: _pendingNumber,
      state: _state,
      tradeClass: _tradeClass,
      result: _pending,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_pending != null) return _buildConfirm(c);
    return _buildEntry(c);
  }

  Widget _buildConfirm(JColors c) {
    final pending = _pending!;
    final detail = pending is VerifyFailed
        ? pending.detail
        : pending is VerifyManualReview
        ? pending.reason
        : 'We couldn\'t confirm this licence automatically.';
    final allowUpload = pending is VerifyManualReview
        ? true
        : pending is VerifyFailed
        ? pending.manualFallbackAllowed
        : true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We couldn\'t verify this licence',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(12.h),
        Text(
          detail,
          style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
        ),
        const Spacer(),
        if (allowUpload) ...[
          SizedBox(
            width: double.infinity,
            child: JButton(
              label: 'UPLOAD DOCUMENT INSTEAD',
              variant: JButtonVariant.secondary,
              size: JButtonSize.standard,
              onPressed: () => showManualUploadSheet(
                context: context,
                docType: DocType.tradeLicence,
              ),
            ),
          ),
          Gap(12.h),
        ],
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'TRY AGAIN',
                variant: JButtonVariant.secondary,
                size: JButtonSize.standard,
                onPressed: () => setState(() {
                  _pending = null;
                  _pendingNumber = null;
                }),
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'CONTINUE',
                variant: JButtonVariant.primary,
                size: JButtonSize.standard,
                onPressed: _continueWithResult,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEntry(JColors c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.stepLabel,
          style: TextStyle(
            fontSize: 11.sp,
            color: c.text3,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.h),
        Text(
          'Your licence',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(16.h),
        FormBuilder(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DropdownRow(
                label: 'STATE',
                value: _state,
                items: _states,
                onChanged: (v) => setState(() => _state = v),
              ),
              Gap(12.h),
              _DropdownRow(
                label: 'TRADE CLASS',
                value: _tradeClass,
                items: _classes,
                onChanged: (v) => setState(() => _tradeClass = v),
              ),
              Gap(12.h),
              JTextField(
                name: 'licence_number',
                label: 'Licence number',
                hint: 'e.g. EL-12345',
                enabled: !_calling,
              ),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          Gap(8.h),
          Text(
            _errorMessage!,
            style: TextStyle(fontSize: 13.sp, color: c.urgent),
          ),
        ],
        const Spacer(),
        if (_calling)
          Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Row(
              children: [
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                Gap(12.w),
                Expanded(
                  child: Text(
                    'Checking with $_state Fair Trading\'s public register…',
                    style: TextStyle(fontSize: 13.sp, color: c.text2),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'SKIP',
                variant: JButtonVariant.secondary,
                size: JButtonSize.standard,
                onPressed: _calling ? null : widget.onSkip,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'VERIFY',
                variant: JButtonVariant.primary,
                size: JButtonSize.standard,
                onPressed: _calling ? null : _onVerify,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DropdownRow extends StatelessWidget {
  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            color: c.text3,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(6.h),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(color: c.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: value,
              dropdownColor: c.surface,
              style: TextStyle(fontSize: 14.sp, color: c.text1),
              items: items
                  .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                  .toList(),
              onChanged: (v) => v == null ? null : onChanged(v),
            ),
          ),
        ),
      ],
    );
  }
}
