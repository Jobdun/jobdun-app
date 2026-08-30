import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Label above an input, a chip group, or a page section.
///
/// Two looks, one widget:
///
/// - **Default** — the wide-tracked muted micro-label used above raw inputs
///   across /profile/edit and /jobs/create. Pairs with the flat-input style.
/// - **[FieldLabel.section]** — the 16dp bold heading the Figma refresh puts
///   above every page section (profile node 134:8710, settings node 134:9191,
///   job details node 134:13365). Sentence case: pass "About the company",
///   not "ABOUT THE COMPANY".
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key}) : _section = false;

  /// Section heading on a screen rebuilt from the Figma refresh.
  const FieldLabel.section(this.text, {super.key}) : _section = true;

  final String text;
  final bool _section;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    if (_section) {
      return Text(
        text,
        style: tt.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.0,
          color: c.text1,
        ),
      );
    }
    return Text(
      text,
      style: tt.labelSmall!.copyWith(letterSpacing: 0.12 * 11, color: c.text3),
    );
  }
}
