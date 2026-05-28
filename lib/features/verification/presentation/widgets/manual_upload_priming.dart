import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';

/// The four-bullet priming card that used to live on the wizard intro
/// screen. Now baked into the manual sheet itself so trades who route
/// straight here (every trade, per 2026-05-29) still get the photo-quality
/// hint, accepted formats, and the honest "a person reviews this" SLA
/// before they hit camera/gallery. Removing the priming would land us
/// with blurry photos, wrong doc types, and expectations of instant
/// approval — all things the intro screen was quietly fixing.
class ManualUploadPrimingBlock extends StatelessWidget {
  const ManualUploadPrimingBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: c.actionBg,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: c.action.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.info, size: 16.r, color: c.action),
              Gap(8.w),
              Text(
                'BEFORE YOU UPLOAD',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: c.text1,
                ),
              ),
            ],
          ),
          Gap(10.h),
          const _PrimingBullet(text: 'All 4 edges of the document in frame'),
          const _PrimingBullet(text: 'No glare or fingers covering text'),
          const _PrimingBullet(text: 'JPG, PNG, WebP, or HEIC — up to 10 MB'),
          const _PrimingBullet(
            text: 'A real person reviews it — usually within 24 hours',
          ),
        ],
      ),
    );
  }
}

class _PrimingBullet extends StatelessWidget {
  const _PrimingBullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 7.h),
            child: Container(
              width: 4.r,
              height: 4.r,
              decoration: BoxDecoration(
                color: c.action,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.sp, color: c.text2, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
