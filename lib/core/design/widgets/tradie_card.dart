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
    final c = context.c;
    final isOffline = !isAvailable;

    return Opacity(
      opacity: isOffline ? 0.45 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AvatarBlock(initials: initials, size: 44, bg: avatarColor),
                  Gap(12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: GoogleFonts.openSans(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                  color: c.text1,
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
                                  style: GoogleFonts.oswald(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w700,
                                    color: c.text1,
                                    height: 1,
                                  ),
                                ),
                                Text(
                                  '/5',
                                  style: GoogleFonts.openSans(
                                    fontSize: 11.sp,
                                    color: c.text3,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Gap(2.h),
                        Text(
                          '$trade · $suburb',
                          style: GoogleFonts.openSans(
                            fontSize: 13.sp,
                            color: c.text2,
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          '$jobCount jobs completed',
                          style: GoogleFonts.openSans(
                            fontSize: 11.sp,
                            color: c.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12.h),
                child: Divider(height: 1, color: c.border),
              ),
              Row(
                children: [
                  Container(
                    width: 6.r,
                    height: 6.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isOffline ? c.text3 : c.verified,
                    ),
                  ),
                  Gap(8.w),
                  Text(
                    isOffline ? 'Offline' : 'Available',
                    style: GoogleFonts.openSans(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: isOffline ? c.text3 : c.verifiedTx,
                    ),
                  ),
                  if (!isOffline && isVerified) ...[
                    Gap(8.w),
                    Text('·', style: GoogleFonts.openSans(fontSize: 11.sp, color: c.border)),
                    Gap(8.w),
                    Text(
                      '✓ Verified',
                      style: GoogleFonts.openSans(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: c.verifiedTx,
                      ),
                    ),
                  ],
                  if (!isOffline) ...[
                    const Spacer(),
                    Text(
                      '${distanceKm.toStringAsFixed(1)} km',
                      style: GoogleFonts.oswald(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                        color: c.action,
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
