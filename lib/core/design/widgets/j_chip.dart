import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme/app_colors.dart';

/// Solid identity / critical-alert chip — the canonical implementation for
/// chips whose presence is itself a signal (role chip on the profile header,
/// "URGENT" badge on a job card, trade-type identity chip).
///
/// **Defaults to white-on-orange.** Override [backgroundColor] / [foregroundColor]
/// only when the surrounding composition demands it (e.g. a green
/// confirmation chip would pass `c.verified` / `Colors.white`).
///
/// **Chip vocabulary in this codebase.** Pick the right widget by intent:
///
/// - [JChip]      — solid identity / critical alert. *This file.*
/// - `GvChip`     — toggleable filter pill (`design/widgets/gv_chip.dart`).
/// - `StatusBadge` — translucent semantic status with optional dot prefix,
///                   variants `verified / available / urgent / pending / pro`
///                   (`design/widgets/status_badge.dart`).
///
/// Do not unify these under one widget — different jobs, different visual
/// rules, different semantic load.
class JChip extends StatelessWidget {
  const JChip({
    super.key,
    required this.label,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final bg = backgroundColor ?? c.action;
    final fg = foregroundColor ?? c.onAction;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
      ),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall!.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: fg,
        ),
      ),
    );
  }
}
