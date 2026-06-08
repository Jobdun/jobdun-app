import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../domain/entities/trade_profile.dart';

/// Honest availability state for the tradie profile banner.
///
/// `availableNow` follows the same rule search uses (`isAvailable ||
/// availableFrom <= today`) so the profile never claims a tradie is booked
/// when search would already surface them as free.
enum AvailabilityStatus { availableNow, availableFrom, unavailable, unknown }

class AvailabilityView {
  const AvailabilityView(this.status, this.label);
  final AvailabilityStatus status;
  final String label;
}

/// Pure mapping from a trade profile to its availability line. Pulled out of
/// the widget so the date/branch logic is unit-tested without pumping a frame.
AvailabilityView availabilityDisplay(TradeProfile? p, {DateTime? now}) {
  if (p == null) return const AvailabilityView(AvailabilityStatus.unknown, '—');

  final today = now ?? DateTime.now();
  final from = p.availableFrom;
  final freeFromArrived = from != null && !from.isAfter(today);

  if (p.isAvailable || freeFromArrived) {
    return const AvailabilityView(
      AvailabilityStatus.availableNow,
      'Available now',
    );
  }
  if (from != null) {
    return AvailabilityView(
      AvailabilityStatus.availableFrom,
      'Available from ${DateFormat('d MMM').format(from)}',
    );
  }
  return const AvailabilityView(
    AvailabilityStatus.unavailable,
    'Not available right now',
  );
}

/// Tradie profile banner. Splits two facts the old banner conflated: the
/// real **availability** line (driven by the profile) and the **verified**
/// signal (driven by the verifications table). The colour cue lives on the
/// icon; the label stays primary-text so it always clears WCAG AA.
class ProfileAvailabilityBanner extends StatelessWidget {
  const ProfileAvailabilityBanner({
    super.key,
    required this.profile,
    required this.isVerified,
    this.now,
  });

  final TradeProfile? profile;
  final bool isVerified;

  /// Test seam — defaults to `DateTime.now()` via [availabilityDisplay].
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final view = availabilityDisplay(profile, now: now);

    final (IconData icon, Color iconColor) = switch (view.status) {
      AvailabilityStatus.availableNow => (AppIcons.successCircle, c.available),
      AvailabilityStatus.availableFrom => (AppIcons.calendar, c.warning),
      AvailabilityStatus.unavailable => (AppIcons.clock, c.text3),
      AvailabilityStatus.unknown => (AppIcons.clock, c.text3),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 12.h,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md.r, color: iconColor),
          Gap(10.w),
          Expanded(
            child: Text(
              view.label,
              style: tt.bodyLarge!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text1,
              ),
            ),
          ),
          if (isVerified) ...[Gap(8.w), const _VerifiedPill()],
        ],
      ),
    );
  }
}

class _VerifiedPill extends StatelessWidget {
  const _VerifiedPill();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: c.verifiedBg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: c.verified),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.verified, size: AppIconSize.micro.r, color: c.verified),
          Gap(4.w),
          Text(
            'VERIFIED',
            style: tt.labelMedium!.copyWith(
              color: c.verifiedTx,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
