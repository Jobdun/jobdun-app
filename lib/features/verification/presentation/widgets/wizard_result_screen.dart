import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/verification.dart';

/// Wizard final screen. Lists what was checked and the regulator result(s).
/// Honest copy: shows verified rows AND failed rows; never lies about state.
class WizardResultScreen extends StatelessWidget {
  const WizardResultScreen({
    super.key,
    required this.abnResult,
    required this.licenceResult,
    required this.abn,
    required this.licenceNumber,
    required this.licenceState,
    required this.licenceTradeClass,
    required this.onFinish,
  });

  final VerifyResult? abnResult;
  final VerifyResult? licenceResult;
  final String? abn;
  final String? licenceNumber;
  final String? licenceState;
  final String? licenceTradeClass;
  final VoidCallback onFinish;

  bool get _abnVerified => abnResult is VerifyVerified;
  bool get _licenceVerified => licenceResult is VerifyVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final allGood = _abnVerified && (licenceResult == null || _licenceVerified);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          allGood ? AppIcons.verified : AppIcons.shield,
          size: 56.r,
          color: allGood ? c.verified : c.text3,
        ),
        Gap(12.h),
        Text(
          allGood ? 'You\'re verified' : 'Here\'s what we checked',
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(20.h),
        Expanded(
          child: ListView(
            children: [
              if (abnResult != null)
                _ResultRow(
                  label: 'Business (ABN $abn)',
                  result: abnResult!,
                  regulatorFallback: 'Australian Business Register',
                ),
              if (licenceResult != null) ...[
                Gap(12.h),
                _ResultRow(
                  label: _licenceLabel(),
                  result: licenceResult!,
                  regulatorFallback: licenceState != null
                      ? '$licenceState Fair Trading\'s public register'
                      : 'the state regulator',
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'CONTINUE',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }

  String _licenceLabel() {
    final cls = licenceTradeClass ?? 'Licence';
    final num = licenceNumber ?? '';
    return num.isEmpty ? cls : '$cls $num';
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.result,
    required this.regulatorFallback,
  });

  final String label;
  final VerifyResult result;
  final String regulatorFallback;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (result is VerifyVerified) {
      final v = result as VerifyVerified;
      final regulator = v.regulatorDisplayName ?? regulatorFallback;
      final expires = v.expiresAt != null
          ? ' · expires ${DateFormat('d MMM yyyy').format(v.expiresAt!)}'
          : '';
      return _row(
        c,
        icon: AppIcons.verified,
        title: label,
        sub: 'Checked against $regulator$expires',
        positive: true,
      );
    }
    if (result is VerifyFailed) {
      final f = result as VerifyFailed;
      return _row(
        c,
        icon: AppIcons.closeCircle,
        title: label,
        sub: f.detail.isNotEmpty ? f.detail : 'Verification failed.',
        positive: false,
      );
    }
    if (result is VerifyManualReview) {
      return _row(
        c,
        icon: AppIcons.shield,
        title: label,
        sub: 'We\'re checking this manually — usually under 24 hours.',
        positive: false,
      );
    }
    return const SizedBox.shrink();
  }

  Widget _row(
    JColors c, {
    required IconData icon,
    required String title,
    required String sub,
    required bool positive,
  }) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: positive ? c.verifiedBg : c.surface,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: positive ? c.verified : c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: positive ? c.verified : c.text3, size: 22.r),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: c.text1,
                  ),
                ),
                Gap(4.h),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: positive ? c.verifiedTx : c.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
