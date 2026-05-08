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
    final c = context.c;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.ease,
        height: 30.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? c.action : c.surfaceRaised,
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
          border: Border.all(
            color: active ? c.action : c.border,
          ),
        ),
        child: Text(
          label.toUpperCase(),
          style: GoogleFonts.openSans(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: active ? Colors.white : c.text2,
          ),
        ),
      ),
    );
  }
}
