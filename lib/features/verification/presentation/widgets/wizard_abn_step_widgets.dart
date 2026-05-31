import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';

/// Confirm screens for [WizardAbnStep]. Extracted here so the parent file
/// stays under the 500-LOC ceiling. All four are public because they live
/// in a separate file from their single caller — but the type signatures
/// keep them tightly scoped to the wizard's contract (entity name, attest
/// callback, navigation deep link to /profile/verify-phone).

/// "Is this your business?" — hardened with an attestation checkbox. The
/// regulator confirmed the ABN exists; this is where the user is asked to
/// stake their identity on operating the business. The funnel event written
/// after attestation is the audit anchor if Trust & Safety ever has to
/// review a fraud report.
class ConfirmYourBusiness extends StatefulWidget {
  const ConfirmYourBusiness({
    super.key,
    required this.abn,
    required this.entityName,
    required this.onAttest,
    required this.onEdit,
  });

  final String abn;
  final String? entityName;
  final Future<void> Function() onAttest;
  final VoidCallback onEdit;

  @override
  State<ConfirmYourBusiness> createState() => _ConfirmYourBusinessState();
}

class _ConfirmYourBusinessState extends State<ConfirmYourBusiness> {
  bool _attested = false;
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final entity = widget.entityName?.toUpperCase() ?? 'Active business';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Is this your business?',
          style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
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
                entity,
                style: tt.titleLarge!.copyWith(fontWeight: FontWeight.w700),
              ),
              Gap(8.h),
              Text('ABN ${widget.abn}', style: tt.bodyMedium),
            ],
          ),
        ),
        Gap(16.h),
        InkWell(
          onTap: _submitting
              ? null
              : () => setState(() => _attested = !_attested),
          borderRadius: BorderRadius.circular(8.r),
          child: Padding(
            padding: EdgeInsets.all(4.r),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: Checkbox(
                      value: _attested,
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _attested = v ?? false),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
                Gap(10.w),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text:
                              'I attest that I am authorised to act on '
                              'behalf of ',
                        ),
                        TextSpan(
                          text: entity,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(
                          text:
                              '. False attestations may be referred to the '
                              'ATO and law enforcement.',
                        ),
                      ],
                    ),
                    style: tt.bodySmall!.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
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
                onPressed: _submitting ? null : widget.onEdit,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'YES, THAT\'S ME',
                variant: JButtonVariant.primary,
                size: JButtonSize.standard,
                onPressed: (_attested && !_submitting) ? _onAttest : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onAttest() async {
    setState(() => _submitting = true);
    await widget.onAttest();
    if (mounted) setState(() => _submitting = false);
  }
}

/// Shown when the server returns `reason='phone_required'` — the verify-abn
/// precondition gate. Deep-links to the existing phone-verification flow.
class ConfirmPhoneRequired extends StatelessWidget {
  const ConfirmPhoneRequired({
    super.key,
    required this.detail,
    required this.onBack,
  });

  final String detail;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verify your phone first',
          style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        Gap(12.h),
        Text(detail, style: tt.bodyMedium),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'VERIFY MY PHONE',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: () => context.push('/profile/verify-phone'),
          ),
        ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'BACK',
            variant: JButtonVariant.secondary,
            size: JButtonSize.standard,
            onPressed: onBack,
          ),
        ),
      ],
    );
  }
}

class ConfirmAbnFailed extends StatelessWidget {
  const ConfirmAbnFailed({
    super.key,
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
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We couldn\'t verify this ABN',
          style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        Gap(12.h),
        Text(detail, style: tt.bodyMedium),
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

class ConfirmAbnManualReview extends StatelessWidget {
  const ConfirmAbnManualReview({
    super.key,
    required this.reason,
    required this.onContinue,
    required this.onUpload,
  });

  final String reason;
  final VoidCallback onContinue;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'We\'ll finish this manually',
          style: tt.headlineMedium!.copyWith(fontWeight: FontWeight.w700),
        ),
        Gap(12.h),
        Text(
          'We couldn\'t reach the Australian Business Register right now. '
          'Upload a copy of your ABN certificate and a reviewer will '
          'confirm it within 24 hours.',
          style: tt.bodyMedium,
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
