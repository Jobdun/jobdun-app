import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:jobdun/app/theme/app_icon_size.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification.dart';

/// Wizard final screen. Honest about what was checked: green check when the
/// role-relevant kind verified, neutral "here's what we checked" when there
/// were attempts that didn't fully succeed, and a friendly "you can do this
/// later" when the user skipped without trying.
///
/// `role` is required so "did we succeed?" is computed against the right kind
/// (trade → licence, builder → ABN) — the prior dual-step shape that AND'd
/// both kinds together always read false in v2.1 because the irrelevant kind
/// is never collected.
class WizardResultScreen extends StatelessWidget {
  const WizardResultScreen({
    super.key,
    required this.role,
    required this.abnResult,
    required this.licenceResult,
    required this.abn,
    required this.licenceNumber,
    required this.licenceState,
    required this.licenceTradeClass,
    required this.onFinish,
  });

  final UserRole role;
  final VerifyResult? abnResult;
  final VerifyResult? licenceResult;
  final String? abn;
  final String? licenceNumber;
  final String? licenceState;
  final String? licenceTradeClass;
  final VoidCallback onFinish;

  bool get _abnVerified => abnResult is VerifyVerified;
  bool get _licenceVerified => licenceResult is VerifyVerified;

  bool get _allGood => role == UserRole.trade ? _licenceVerified : _abnVerified;
  bool get _didAttempt => abnResult != null || licenceResult != null;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (icon, iconColor, title, subtitle) = _headerCopy(c);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppIconSize.hero.r, color: iconColor),
        Gap(12.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        if (subtitle != null) ...[
          Gap(6.h),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
          ),
        ],
        Gap(20.h),
        Expanded(child: _buildBody(c)),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: _allGood ? 'DONE' : 'CONTINUE',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: onFinish,
          ),
        ),
      ],
    );
  }

  (IconData, Color, String, String?) _headerCopy(JColors c) {
    if (_allGood) {
      return (
        AppIcons.verified,
        c.verified,
        'You\'re verified',
        'Builders will see your receipt on your profile.',
      );
    }
    if (_didAttempt) {
      return (
        AppIcons.shield,
        c.text3,
        'Here\'s what we checked',
        'You can finish verification any time — your profile still works.',
      );
    }
    // No attempt — user skipped the auto-check.
    return (
      AppIcons.shield,
      c.text3,
      'You can verify any time',
      'Open this from your profile when you\'re ready. Verification is '
          'optional — you can apply, post, and message either way.',
    );
  }

  Widget _buildBody(JColors c) {
    if (!_didAttempt) return const SizedBox.shrink();
    return ListView(
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
          Icon(
            icon,
            color: positive ? c.verified : c.text3,
            size: AppIconSize.md.r,
          ),
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
