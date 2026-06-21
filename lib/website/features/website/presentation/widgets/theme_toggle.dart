import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../providers/theme_mode_provider.dart';

/// Sun/moon control in the marketing-site nav. One tap flips light↔dark and
/// persists the choice (see [ThemeModeNotifier.toggle]).
///
/// Accessibility: a real [Tooltip] + [IconButton] so it's keyboard-focusable
/// with a visible focus ring, exposes a dynamic [Semantics] label to screen
/// readers ("Switch to light/dark mode"), and clears the 44×44 target floor.
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final mode = ref.watch(themeModeProvider);
    final platform = MediaQuery.platformBrightnessOf(context);
    final showingDark = isShowingDark(mode, platform);

    // Show the glyph for the mode you'd switch *to*, the common toggle idiom.
    final icon = showingDark ? AppIcons.sun : AppIcons.moon;
    final label = showingDark ? 'Switch to light mode' : 'Switch to dark mode';

    return Tooltip(
      message: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: c.surfaceRaised.withValues(alpha: 0.6),
          shape: CircleBorder(side: BorderSide(color: c.border)),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: () =>
                ref.read(themeModeProvider.notifier).toggle(platform),
            iconSize: 20.r,
            color: c.text1,
            icon: Icon(icon),
            tooltip: label,
          ),
        ),
      ),
    );
  }
}
