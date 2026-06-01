import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/design/widgets/jobdun_logo.dart';

/// The admin identity lockup: the universal JOBDUN badge beside the wordmark and
/// a console label. One source of truth for the brand mark across the admin web
/// app (sidebar header + login) so the badge, wordmark, and spacing stay
/// identical wherever the brand appears. For the bare badge (collapsed rail,
/// favicons) use [JobdunLogo] with `LogoVariant.badge` directly.
class AdminBrandLockup extends StatelessWidget {
  const AdminBrandLockup({
    super.key,
    this.badgeSize = 28,
    this.label = 'ADMIN',
  });

  /// Height of the circular badge in logical px; the wordmark sits at its fixed
  /// scale beside it.
  final double badgeSize;

  /// Sub-label under the wordmark — 'ADMIN' for the console identity.
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        JobdunLogo(variant: LogoVariant.badge, height: badgeSize),
        Gap(badgeSize * 0.42),
        // Flexible + clip so the wordmark never overflows a narrow host (the
        // 240px sidebar rail); on the wide login panel there's room to spare.
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'JOBDUN',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: AdminText.wordmark(c.text1),
              ),
              const Gap(2),
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: AdminText.eyebrow(c.action).copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
