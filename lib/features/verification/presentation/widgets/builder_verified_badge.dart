import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/builder_public_verification.dart';
import '../../domain/entities/verification.dart';
import '../providers/verifications_provider.dart';

/// Counterparty trust signal — a compact "Verified business" badge shown to the
/// OTHER party (a trade viewing a builder). Reads the minimized public
/// projection (`builderPublicVerificationProvider`) — never the raw
/// verification row, ABN number, or failure reasons. Renders nothing while
/// loading or when the builder isn't verified, so it's safe to drop into any
/// row without reserving space.
class BuilderVerifiedBadge extends ConsumerWidget {
  const BuilderVerifiedBadge({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref
        .watch(builderPublicVerificationProvider(userId))
        .asData
        ?.value;
    if (rows == null) return const SizedBox.shrink();

    BuilderPublicVerification? abn;
    for (final r in rows) {
      if (r.kind == VerificationKind.abn) {
        abn = r;
        break;
      }
    }
    if (abn == null) return const SizedBox.shrink();

    final c = context.c;
    final gst = abn.gstRegistered == true ? ' · GST registered' : '';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(AppIcons.verified, size: 13.r, color: c.verified),
        Gap(4.w),
        Flexible(
          child: Text(
            'Verified business$gst',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: c.verified,
            ),
          ),
        ),
      ],
    );
  }
}
