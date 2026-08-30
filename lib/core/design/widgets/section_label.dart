import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Section heading inside a scrolling screen body — "Cover note",
/// "Availability", "Formal quote".
///
/// Figma `JobDun-Screens` sets these in Inter Bold 16 at full primary ink
/// (e.g. Applicant, node 124:5934). That is a deliberate step up from
/// [FieldLabel], the small wide-tracked uppercase eyebrow that sits above raw
/// inputs: an eyebrow whispers what a field is, a section label announces a
/// block of content. Use [FieldLabel] in forms, this in read screens.
///
/// **Casing.** Passed through untouched — the mock reads "Cover Note", not
/// "COVER NOTE".
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: context.c.text1,
    ),
  );
}
