import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';

typedef OnAbnSuccess =
    void Function({required String abn, required VerifyResult result});

/// Wizard Step 1: ABN entry + confirmation. Calls the verify-abn Edge
/// Function, then shows a "Is this your business?" screen on success.
class WizardAbnStep extends ConsumerStatefulWidget {
  const WizardAbnStep({
    super.key,
    required this.stepLabel,
    required this.onSuccess,
  });

  final String stepLabel;
  final OnAbnSuccess onSuccess;

  @override
  ConsumerState<WizardAbnStep> createState() => _WizardAbnStepState();
}

class _WizardAbnStepState extends ConsumerState<WizardAbnStep> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _calling = false;
  String? _errorMessage;
  VerifyResult? _pending;
  String _abn = '';

  Future<void> _onNext() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final abn = (_formKey.currentState!.value['abn'] as String? ?? '')
        .replaceAll(RegExp(r'\s+'), '');
    final abnError = Validators.abn(abn);
    if (abnError != null || abn.length != 11) {
      setState(
        () =>
            _errorMessage = abnError ?? 'That doesn\'t look like a valid ABN.',
      );
      return;
    }
    setState(() {
      _calling = true;
      _errorMessage = null;
    });
    final result = await ref.read(invokeVerifyAbnUseCaseProvider).call(abn);
    if (!mounted) return;
    result.fold(
      (f) => setState(() {
        _calling = false;
        _errorMessage = f.message;
      }),
      (r) => setState(() {
        _calling = false;
        _abn = abn;
        _pending = r;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_pending != null) return _buildConfirm(context, c);
    return _buildEntry(context, c);
  }

  Widget _buildEntry(BuildContext context, JColors c) {
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
          'Your business',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(16.h),
        FormBuilder(
          key: _formKey,
          child: JTextField(
            name: 'abn',
            label: 'Australian Business Number (ABN)',
            hint: '11 digits',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 11,
            enabled: !_calling,
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
                    'Checking with the Australian Business Register…',
                    style: TextStyle(fontSize: 13.sp, color: c.text2),
                  ),
                ),
              ],
            ),
          ),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'NEXT',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: _calling ? null : _onNext,
          ),
        ),
      ],
    );
  }

  Widget _buildConfirm(BuildContext context, JColors c) {
    final pending = _pending;
    if (pending == null) return const SizedBox.shrink();

    if (pending is VerifyFailed) {
      return _ConfirmFailed(
        detail: pending.detail,
        manualFallbackAllowed: pending.manualFallbackAllowed,
        onTryAgain: () => setState(() => _pending = null),
        onUpload: pending.manualFallbackAllowed
            ? () => showManualUploadSheet(
                context: context,
                docType: DocType.abnCertificate,
              )
            : null,
      );
    }
    if (pending is VerifyManualReview) {
      return _ConfirmManualReview(
        reason: pending.reason,
        onContinue: () => widget.onSuccess(abn: _abn, result: pending),
        onUpload: () => showManualUploadSheet(
          context: context,
          docType: DocType.abnCertificate,
        ),
      );
    }
    if (pending is VerifyVerified) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Is this your business?',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          Gap(20.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pending.entityName?.toUpperCase() ?? 'Active business',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                Gap(8.h),
                Text(
                  'ABN $_abn',
                  style: TextStyle(fontSize: 13.sp, color: c.text2),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'NO, EDIT ABN',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.standard,
                  onPressed: () => setState(() => _pending = null),
                ),
              ),
              Gap(12.w),
              Expanded(
                child: JButton(
                  label: 'YES, THAT\'S ME',
                  variant: JButtonVariant.primary,
                  size: JButtonSize.standard,
                  onPressed: () => widget.onSuccess(abn: _abn, result: pending),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

class _ConfirmFailed extends StatelessWidget {
  const _ConfirmFailed({
    required this.detail,
    required this.manualFallbackAllowed,
    required this.onTryAgain,
    this.onUpload,
  });

  final String detail;
  final bool manualFallbackAllowed;
  final VoidCallback onTryAgain;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We couldn\'t verify this ABN',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(12.h),
        Text(
          detail,
          style: TextStyle(fontSize: 14.sp, color: c.text2),
        ),
        const Spacer(),
        if (onUpload != null) ...[
          SizedBox(
            width: double.infinity,
            child: JButton(
              label: 'UPLOAD DOCUMENT INSTEAD',
              variant: JButtonVariant.secondary,
              size: JButtonSize.standard,
              onPressed: onUpload,
            ),
          ),
          Gap(12.h),
        ],
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'TRY A DIFFERENT ABN',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: onTryAgain,
          ),
        ),
      ],
    );
  }
}

class _ConfirmManualReview extends StatelessWidget {
  const _ConfirmManualReview({
    required this.reason,
    required this.onContinue,
    required this.onUpload,
  });

  final String reason;
  final VoidCallback onContinue;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We\'ll finish this manually',
          style: TextStyle(
            fontSize: 22.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(12.h),
        Text(
          'We couldn\'t reach the Australian Business Register right now. '
          'Upload a copy of your ABN certificate and a reviewer will '
          'confirm it within 24 hours.',
          style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'UPLOAD DOCUMENT',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: onUpload,
          ),
        ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'CONTINUE WITHOUT UPLOAD',
            variant: JButtonVariant.secondary,
            size: JButtonSize.standard,
            onPressed: onContinue,
          ),
        ),
      ],
    );
  }
}
