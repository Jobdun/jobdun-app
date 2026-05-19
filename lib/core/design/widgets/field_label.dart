import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

// Uppercase, wide-tracked, muted label used above raw inputs and chip groups
// across /profile/edit and /jobs/create. Pairs with the project's flat-input
// style — keep both surfaces visually aligned.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall!.copyWith(
      letterSpacing: 0.12 * 11,
      color: context.c.text3,
    ),
  );
}
