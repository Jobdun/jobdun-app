import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/app_colors.dart';
import 'avatar_block.dart';

class TradieCard extends StatelessWidget {
  const TradieCard({
    super.key,
    required this.name,
    required this.trade,
    required this.suburb,
    required this.rating,
    required this.jobCount,
    required this.isVerified,
    required this.isAvailable,
    required this.distanceKm,
    required this.initials,
    this.onTap,
    this.avatarColor,
  });

  final String name;
  final String trade;
  final String suburb;
  final double rating;
  final int jobCount;
  final bool isVerified;
  final bool isAvailable;
  final double distanceKm;
  final String initials;
  final VoidCallback? onTap;
  final Color? avatarColor;

  @override
  Widget build(BuildContext context) {
    final isOffline = !isAvailable;

    return Opacity(
      opacity: isOffline ? 0.45 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top: avatar + name/trade/jobs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarBlock(initials: initials, size: 44, bg: avatarColor),
                  Gap(12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name + rating on same row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.barlow(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text1,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  rating.toStringAsFixed(1),
                                  style: GoogleFonts.barlowCondensed(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text1,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '/5',
                                  style: GoogleFonts.barlow(
                                    fontSize: 11.sp,
                                    color: AppColors.text3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Gap(2.h),
                        Text(
                          '$trade · $suburb',
                          style: GoogleFonts.barlow(
                            fontSize: 13.sp,
                            color: AppColors.text2,
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          '$jobCount jobs completed',
                          style: GoogleFonts.barlow(
                            fontSize: 11.sp,
                            color: AppColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Divider
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(height: 1, color: AppColors.border),
              ),
              // Footer: ● status · ✓ Verified   distance→
              Row(
                children: [
                  Container(
                    width: 6.r,
                    height: 6.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOffline ? AppColors.text3 : AppColors.verified,
                    ),
                  ),
                  Gap(8.w),
                  Text(
                    isOffline ? 'Offline' : 'Available',
                    style: GoogleFonts.barlow(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: isOffline ? AppColors.text3 : AppColors.verifiedTx,
                    ),
                  ),
                  if (!isOffline && isVerified) ...[
                    Gap(8.w),
                    Text(
                      '·',
                      style: GoogleFonts.barlow(
                        fontSize: 11.sp,
                        color: AppColors.border,
                      ),
                    ),
                    Gap(8.w),
                    Text(
                      '✓ Verified',
                      style: GoogleFonts.barlow(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.verifiedTx,
                      ),
                    ),
                  ],
                  if (!isOffline) ...[
                    const Spacer(),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.action,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
