import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';

class AvatarBlock extends StatelessWidget {
  const AvatarBlock({
    super.key,
    required this.initials,
    this.size = 44,
    this.bg,
  });

  final String initials;
  final double size;
  final Color? bg;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final fs = size >= 64 ? 22.0 : size >= 50 ? 16.0 : 14.0;

    return Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        color: bg ?? c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.avatar.r),
      ),
      child: Center(
        child: Text(
          initials,
          style: GoogleFonts.barlowCondensed(
            fontSize: fs.sp,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.04 * fs,
            color: c.text1,
          ),
        ),
      ),
    );
  }
}
