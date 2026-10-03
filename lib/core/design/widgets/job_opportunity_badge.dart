import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../colors.dart';

/// A neutral label distinguishing an apprenticeship from a trade-job invitation.
class JobOpportunityBadge extends StatelessWidget {
  const JobOpportunityBadge({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
    decoration: BoxDecoration(
      color: context.c.surfaceRaised,
      borderRadius: BorderRadius.circular(AppRadius.chip.r),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium!.copyWith(
        color: context.c.text1,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
