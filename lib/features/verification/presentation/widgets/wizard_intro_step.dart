import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification_document.dart';

/// Wizard step 0 — "How would you like to verify?"
///
/// Role-scoped:
///   Builder → ABN path (regulator) or ABN certificate upload
///   Trade   → Licence path (regulator) or trade-licence upload
///
/// Two co-equal CTAs so users with paper-only docs, unsupported states, or a
/// "just take the photo, I don't have the number handy" mindset don't have to
/// fail the regulator path first. The auto-path remains the visual primary —
/// the moat is the API-first verification rate, not blanket manual coverage.
class WizardIntroStep extends StatelessWidget {
  const WizardIntroStep({
    super.key,
    required this.role,
    required this.onChooseAutomatic,
    required this.onChooseManual,
  });

  final UserRole role;
  final VoidCallback onChooseAutomatic;
  final VoidCallback onChooseManual;

  bool get _isBuilder => role == UserRole.builder;

  String get _title =>
      _isBuilder ? 'Verify your business' : 'Verify your trade licence';

  String get _body => _isBuilder
      ? 'Pick how you\'d like to do this. The automatic check uses the '
            'Australian Business Register — about 15 seconds.'
      : 'Pick how you\'d like to do this. The automatic check uses your '
            'state regulator\'s public register — about a minute.';

  String get _autoSubtitle => _isBuilder
      ? 'We check your ABN with the Australian Business Register.'
      : 'We check your licence with your state regulator.';

  String get _manualSubtitle =>
      'Upload a clear photo. A reviewer confirms it within 24 hours.';

  DocType get manualDocType =>
      _isBuilder ? DocType.abnCertificate : DocType.tradeLicence;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HOW WOULD YOU LIKE TO VERIFY?',
          style: TextStyle(
            fontSize: 11.sp,
            color: c.text3,
            letterSpacing: 0.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.h),
        Text(
          _title,
          style: TextStyle(
            fontSize: 24.sp,
            fontWeight: FontWeight.w700,
            color: c.text1,
          ),
        ),
        Gap(8.h),
        Text(
          _body,
          style: TextStyle(fontSize: 14.sp, color: c.text2, height: 1.45),
        ),
        Gap(24.h),
        _ChoiceCard(
          icon: AppIcons.shield,
          title: 'VERIFY AUTOMATICALLY',
          subtitle: _autoSubtitle,
          eta: 'About a minute',
          isPrimary: true,
          onTap: onChooseAutomatic,
        ),
        Gap(12.h),
        _ChoiceCard(
          icon: AppIcons.document,
          title: 'UPLOAD A DOCUMENT INSTEAD',
          subtitle: _manualSubtitle,
          eta: '24 hour review',
          isPrimary: false,
          onTap: onChooseManual,
        ),
        const Spacer(),
        Text(
          'Verification is optional. You can apply, post, and message '
          'either way.',
          style: TextStyle(fontSize: 12.sp, color: c.text3, height: 1.45),
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.eta,
    required this.isPrimary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String eta;
  final bool isPrimary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = isPrimary ? c.action : c.text2;
    final bg = isPrimary ? c.actionBg : c.surface;
    final border = isPrimary ? c.action : c.border;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(12.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: border, width: isPrimary ? 1.5 : 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.r,
                height: 44.r,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? c.action.withValues(alpha: 0.15)
                      : c.background,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: accent, size: AppIconSize.md.r),
              ),
              Gap(14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: c.text1,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: c.text2,
                        height: 1.4,
                      ),
                    ),
                    Gap(6.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 2.h,
                      ),
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? c.action.withValues(alpha: 0.18)
                            : c.background,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Text(
                        eta.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
              Icon(
                AppIcons.chevronRight,
                color: accent,
                size: AppIconSize.md.r,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
