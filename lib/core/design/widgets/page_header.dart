import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import 'field_label.dart';

/// Size variant of [PageHeader] — maps directly to existing theme tokens.
///
/// - [hero]  `headlineLarge` (32sp Oswald w700, ls 0.8). Use on `/home` only.
/// - [tab]   `headlineMedium` (24sp Oswald w600, ls 0.5). Use on tab landings
///           (jobs, applications, messages, verification).
/// - [sub]   `headlineSmall` (20sp Oswald w600, ls 0.3). Use on pushed
///           sub-pages (job_create, profile_edit).
enum PageHeaderSize { hero, tab, sub }

/// Canonical page title block — eyebrow + title (+ optional trailing widget).
///
/// **Sizing.** Picks one of three theme tokens via [PageHeaderSize] — see the
/// enum doc above. There is no other "screen title" treatment in the app; if
/// you find yourself doing `headlineSmall.copyWith(fontSize: ...)` in a
/// feature file, add a size to this widget instead.
///
/// **Casing.** The title is uppercased at render time. The casing rule is a
/// [PageHeader] concern, not a global — callers pass title strings in their
/// natural form.
///
/// **No `ShaderMask`.** The brand-flame gradient is reserved for the JOBDUN
/// wordmark in `/login` and `/register` via `AppTheme.brandDisplay`.
/// [PageHeader] is flat `c.text1` only.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    this.size = PageHeaderSize.tab,
    this.trailing,
  });

  final String eyebrow;
  final String title;
  final PageHeaderSize size;
  final Widget? trailing;

  TextStyle _titleStyle(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return switch (size) {
      PageHeaderSize.hero => tt.headlineLarge!,
      PageHeaderSize.tab => tt.headlineMedium!,
      PageHeaderSize.sub => tt.headlineSmall!,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final titleWidget = Text(
      title.toUpperCase(),
      style: _titleStyle(context).copyWith(color: c.text1),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(eyebrow),
        Gap(AppSpacing.xs.h),
        if (trailing == null)
          titleWidget
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              Gap(AppSpacing.sm.w),
              trailing!,
            ],
          ),
      ],
    );
  }
}
