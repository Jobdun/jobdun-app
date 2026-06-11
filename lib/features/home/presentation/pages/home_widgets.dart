part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// The page header is now the floating JTopBar SliverAppBar wired directly in
// home_page.dart (LinkedIn-style avatar + search + notifications).

// ── Stats Row ──────────────────────────────────────────────────────────────────

class _HomeJobsEmpty extends StatelessWidget {
  const _HomeJobsEmpty();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 20.w,
          vertical: AppSpacing.lg.h,
        ),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Icon(AppIcons.search, size: AppIconSize.hero.r, color: c.text3),
            Gap(AppSpacing.sm.h),
            Text(
              'No jobs nearby yet',
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(4.h),
            Text(
              'New jobs in your area will appear here.',
              style: tt.bodyMedium!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
