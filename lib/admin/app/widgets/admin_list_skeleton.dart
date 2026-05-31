import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/design/widgets/j_skeleton_list.dart';

/// Content-shaped loading placeholder for the admin data tables (Users, Jobs,
/// Audit, Verifications). Renders a column of row-shaped bones via
/// [JSkeletonList] so the first-page load matches the loaded layout instead of
/// a bare centred spinner — the house rule from CLAUDE.md ("never a raw
/// CircularProgressIndicator for list/page-body loading").
class AdminListSkeleton extends StatelessWidget {
  const AdminListSkeleton({super.key, this.rows = 8, this.showLeading = true});

  /// Number of placeholder rows to shimmer.
  final int rows;

  /// Whether each row shows a leading square (avatar/icon slot). Off for the
  /// audit log, which has no leading glyph.
  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return JSkeletonList(
      enabled: true,
      child: ListView.builder(
        // Skeletons never scroll — disable so the shimmer reads as one block.
        physics: const NeverScrollableScrollPhysics(),
        itemCount: rows,
        itemBuilder: (context, _) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.border)),
          ),
          child: Row(
            children: [
              if (showLeading) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Gap(12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Placeholder display name',
                      style: AdminText.bodyStrong(c.text1),
                    ),
                    const Gap(6),
                    Text(
                      'placeholder secondary metadata line',
                      style: AdminText.meta(c.text2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
