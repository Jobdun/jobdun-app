import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';

/// Debug-only icon preview gallery (route `/dev/icons`, registered only in
/// kDebugMode). Renders every entry in [AppIcons.catalogue], grouped, so the
/// Tabler migration can be eyeballed end-to-end — any missing/renamed glyph
/// shows as an empty box here instead of failing silently in a screen.
class IconGalleryPage extends StatelessWidget {
  const IconGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    // Preserve catalogue order while grouping.
    final groups =
        <String, List<({String group, String name, IconData icon})>>{};
    for (final entry in AppIcons.catalogue) {
      groups.putIfAbsent(entry.group, () => []).add(entry);
    }

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(title: Text('Dev · Icons (${AppIcons.catalogue.length})')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          children: [
            for (final group in groups.entries) ...[
              Text(
                group.key.toUpperCase(),
                style: tt.titleSmall!.copyWith(
                  color: c.action,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(AppSpacing.md.h),
              Wrap(
                spacing: AppSpacing.sm.w,
                runSpacing: AppSpacing.sm.h,
                children: [
                  for (final entry in group.value)
                    _IconTile(
                      key: ValueKey('gallery-${entry.group}-${entry.name}'),
                      entry: entry,
                    ),
                ],
              ),
              Gap(AppSpacing.xl.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({super.key, required this.entry});

  final ({String group, String name, IconData icon}) entry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: 104.w,
      padding: EdgeInsets.symmetric(
        vertical: AppSpacing.md.h,
        horizontal: AppSpacing.sm.w,
      ),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(entry.icon, size: 28.r, color: c.text1),
          Gap(AppSpacing.sm.h),
          Text(
            entry.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall!.copyWith(color: c.text3, fontSize: 10.sp),
          ),
        ],
      ),
    );
  }
}
