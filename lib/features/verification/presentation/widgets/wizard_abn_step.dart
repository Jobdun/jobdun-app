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
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';
import 'wizard_abn_step_widgets.dart';

typedef OnAbnSuccess =
    void Function({required String abn, required VerifyResult result});

/// Wizard Step 1: ABN entry + confirmation. Calls the verify-abn Edge
/// Function, then shows a "Is this your business?" screen on success that
/// requires an explicit attestation checkbox before the row is treated as
/// owner-confirmed. A `reason='phone_required'` failure from the server
/// (the phone-verified precondition gate) routes to a dedicated screen with
/// a deep link into the phone-verification flow.
///
/// Confirm/failure/manual-review/phone-required panels live in
/// `wizard_abn_step_widgets.dart` to keep this file under the 500-LOC
/// hard ceiling.
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

  Future<void> _onAttestVerified(VerifyVerified pending) async {
    await ref
        .read(verificationFunnelLoggerProvider.notifier)
        .log(
          'abn_attestation_recorded',
          metadata: {
            'abn': _abn,
            'entity_name': pending.entityName,
            'source': 'wizard_abn_step',
          },
        );
    if (!mounted) return;
    widget.onSuccess(abn: _abn, result: pending);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_pending != null) return _buildConfirm(context, c);
    return _buildEntry(context, c);
  }

  Widget _buildEntry(BuildContext context, JColors c) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.stepLabel,
          style: tt.labelSmall!.copyWith(
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.h),
        Text(
          'Your business',
          style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
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
          Text(_errorMessage!, style: tt.bodyMedium!.copyWith(color: c.urgent)),
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
                    style: tt.bodyMedium,
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
      if (pending.reason == 'phone_required') {
        return ConfirmPhoneRequired(
          detail: pending.detail,
          onBack: () => setState(() => _pending = null),
        );
      }
      return ConfirmAbnFailed(
        detail: pending.detail,
        manualFallbackAllowed: pending.manualFallbackAllowed,
        onTryAgain: () => setState(() => _pending = null),
        onUpload: pending.manualFallbackAllowed
            ? () => showManualUploadSheet(
                context: context,
                kind: ManualDocKind.abnCertificate,
                prefilledNumber: _abn,
              )
            : null,
      );
    }
    if (pending is VerifyManualReview) {
      return ConfirmAbnManualReview(
        reason: pending.reason,
        onContinue: () => widget.onSuccess(abn: _abn, result: pending),
        onUpload: () => showManualUploadSheet(
          context: context,
          kind: ManualDocKind.abnCertificate,
          prefilledNumber: _abn,
        ),
      );
    }
    if (pending is VerifyVerified) {
      return ConfirmYourBusiness(
        abn: _abn,
        entityName: pending.entityName,
        onEdit: () => setState(() => _pending = null),
        onAttest: () => _onAttestVerified(pending),
      );
    }
    return const SizedBox.shrink();
  }
}
