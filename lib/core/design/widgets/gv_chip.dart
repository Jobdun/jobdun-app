import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';

class GvChip extends StatelessWidget {
  const GvChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        height: 30.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.foundation : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
          border: Border.all(
            color: active ? AppColors.foundation : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.barlow(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: active ? AppColors.white : AppColors.text2,
          ),
        ),
      ),
    );
  }
}
