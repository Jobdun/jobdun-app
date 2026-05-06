import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/app_colors.dart';

enum AppButtonVariant { primary, action, outline, ghost, text }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final labelStyle = GoogleFonts.barlow(
      fontSize: 13.sp,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.01 * 13,
    );

    final Widget content = isLoading
        ? SizedBox(
            width: 18.r,
            height: 18.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _loaderColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.r),
                SizedBox(width: 8.w),
              ],
              Text(label, style: labelStyle),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.foundation,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.foundation.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          minimumSize: Size.fromHeight(48.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: content,
      ),
      AppButtonVariant.action => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.action,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.action.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.6),
          minimumSize: Size.fromHeight(48.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: content,
      ),
      AppButtonVariant.outline => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text1,
          side: const BorderSide(color: AppColors.text1, width: 1.5),
          minimumSize: Size.fromHeight(48.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.ghost => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.text2,
          backgroundColor: AppColors.card,
          side: const BorderSide(color: AppColors.border),
          minimumSize: Size.fromHeight(48.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
        ),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: AppColors.action,
          minimumSize: Size.fromHeight(48.h),
        ),
        child: content,
      ),
    };
  }

  Color get _loaderColor => switch (variant) {
    AppButtonVariant.primary || AppButtonVariant.action => Colors.white,
    AppButtonVariant.outline => AppColors.text1,
    AppButtonVariant.ghost => AppColors.text2,
    AppButtonVariant.text => AppColors.action,
  };
}
