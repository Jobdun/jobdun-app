import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';

enum PosterVerificationStatus { verified, partial, unverified, unknown }

/// Small chip rendered on job cards in the tradie feed to show whether the
/// poster (builder) has been verified. `unknown` renders nothing for
/// back-compat with existing JobCard call sites that don't pass the status.
class JobCardPosterBadge extends StatelessWidget {
  const JobCardPosterBadge({super.key, required this.status});

  final PosterVerificationStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == PosterVerificationStatus.unknown) {
      return const SizedBox.shrink();
    }
    final c = context.c;
    final verified =
        status == PosterVerificationStatus.verified ||
        status == PosterVerificationStatus.partial;
    final icon = verified ? AppIcons.verified : AppIcons.closeCircle;
    final label = verified ? 'ABN verified' : 'Unverified poster';
    final fg = verified ? c.verified : c.text3;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.r, color: fg),
        Gap(4.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
            color: fg,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
