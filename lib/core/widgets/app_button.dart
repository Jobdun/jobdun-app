import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../app/theme/app_colors.dart';

enum AppButtonVariant { primary, secondary, text }

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
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final labelStyle = tt.labelLarge!.copyWith(color: _labelColor(c));

    final Widget content = isLoading
        ? SizedBox.square(
            dimension: 18.r,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _loaderColor(c),
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18.r),
                Gap(8.w),
              ],
              Text(label.toUpperCase(), style: labelStyle),
            ],
          );

    return switch (variant) {
      AppButtonVariant.primary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.action,
          foregroundColor: Colors.white, // intentional: white-on-action
          disabledBackgroundColor: c.action.withValues(alpha: 0.35),
          disabledForegroundColor: Colors.white.withValues(alpha: 0.5), // intentional: white-on-action
          minimumSize: Size.fromHeight(52.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: content,
      ),
      AppButtonVariant.secondary => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: c.surfaceRaised,
          foregroundColor: c.text1,
          disabledBackgroundColor: c.surfaceRaised.withValues(alpha: 0.5),
          disabledForegroundColor: c.text2,
          minimumSize: Size.fromHeight(52.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.btn.r),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
        child: content,
      ),
      AppButtonVariant.text => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: c.action,
          minimumSize: Size.fromHeight(44.h),
        ),
        child: content,
      ),
    };
  }

  Color _labelColor(JColors c) => switch (variant) {
    AppButtonVariant.primary   => Colors.white, // intentional: white-on-action
    AppButtonVariant.secondary => c.text1,
    AppButtonVariant.text      => c.action,
  };

  Color _loaderColor(JColors c) => switch (variant) {
    AppButtonVariant.primary   => Colors.white, // intentional: white-on-action
    AppButtonVariant.secondary => c.text1,
    AppButtonVariant.text      => c.action,
  };
}
