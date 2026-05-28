import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../domain/entities/verification.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_sheet.dart';
import 'wizard_licence_step_widgets.dart';

typedef OnLicenceDone =
    void Function({
      String? licenceNumber,
      String? state,
      String? tradeClass,
      VerifyResult? result,
    });

/// States with a live `LicenceAdapter` in the verify-licence Edge Function.
/// Mirrors `supabase/functions/_shared/regulators/index.ts`. Update when new
/// adapters land in Phase 7.
///
/// Manual-only launch (2026-05-29): empty list so every state routes to
/// `LicenceUnsupportedHint` → manual upload. The NSW adapter is still a
/// deterministic dev stub (`*00000` → fake-verified) and must not be reachable
/// in production. Restore once a real regulator scraper is wired up AND the
/// server-side `AUTO_VERIFY_ENABLED` flag in
/// `supabase/functions/verify-licence/index.ts` is flipped back to `true`.
const _supportedStates = <String>[];
const _allStates = ['NSW', 'VIC', 'QLD', 'SA', 'WA', 'TAS', 'ACT', 'NT'];

// Starter list — expand per regulator once real adapters land.
const _classes = [
  'Electrician',
  'Plumber',
  'Carpenter',
  'Painter',
  'Tiler',
  'Plasterer',
  'Refrigeration mechanic',
  'Gasfitter',
];

/// Trade-only step: licence entry against a state regulator. When the user
/// picks a state without a live adapter, the screen auto-swaps to a "no
/// automated check yet" hint with a primary "UPLOAD A DOCUMENT INSTEAD" CTA —
/// no Edge Function call is made for unsupported states.
///
/// Confirmation/failure/unsupported-state/phone-required panels live in
/// `wizard_licence_step_widgets.dart` to keep this file under the 500-LOC
/// hard ceiling.
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

  bool get _supported => _supportedStates.contains(_state);

  Future<void> _onVerify() async {
    if (!_supported) return; // auto-routing handled by LicenceUnsupportedHint
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

  Future<void> _openManualUpload({String? prefilledNumber}) async {
    final submitted = await showManualUploadSheet(
      context: context,
      kind: ManualDocKind.tradeLicence,
      prefilledState: _state,
      prefilledNumber: prefilledNumber,
    );
    if (!mounted) return;
    if (submitted) widget.onSkip();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (_pending != null) return _buildConfirm(c);
    return _buildEntry(c);
  }

  Widget _buildConfirm(JColors c) {
    final pending = _pending!;
    if (pending is VerifyFailed && pending.reason == 'phone_required') {
      return LicencePhoneRequired(
        detail: pending.detail,
        onBack: () => setState(() {
          _pending = null;
          _pendingNumber = null;
        }),
      );
    }
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
              onPressed: () =>
                  _openManualUpload(prefilledNumber: _pendingNumber),
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
        LicenceDropdownRow(
          label: 'STATE',
          value: _state,
          items: _allStates,
          onChanged: (v) => setState(() => _state = v),
        ),
        Gap(12.h),
        LicenceDropdownRow(
          label: 'TRADE CLASS',
          value: _tradeClass,
          items: _classes,
          onChanged: (v) => setState(() => _tradeClass = v),
        ),
        Gap(12.h),
        if (_supported)
          LicenceSupportedForm(
            formKey: _formKey,
            calling: _calling,
            state: _state,
            errorMessage: _errorMessage,
            onVerify: _onVerify,
            onSkip: widget.onSkip,
          )
        else
          LicenceUnsupportedHint(
            state: _state,
            onUpload: _openManualUpload,
            onSkip: widget.onSkip,
          ),
      ],
    );
  }
}
