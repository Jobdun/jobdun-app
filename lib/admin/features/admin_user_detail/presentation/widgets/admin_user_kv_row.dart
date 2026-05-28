import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';

/// A single key/value display row used inside detail cards.
/// KEY is rendered as an uppercase letter-spaced caption.
/// Value is rendered below in primary text weight.
/// Pass [valueWidget] for custom value rendering (e.g. status chips, links).
class AdminUserKvRow extends StatelessWidget {
  const AdminUserKvRow({
    super.key,
    required this.label,
    this.value,
    this.valueWidget,
  }) : assert(
         value != null || valueWidget != null,
         'Provide either value or valueWidget',
       );

  final String label;
  final String? value;
  final Widget? valueWidget;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.openSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 2),
          valueWidget ??
              Text(
                value!,
                style: GoogleFonts.openSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: c.text1,
                ),
              ),
        ],
      ),
    );
  }
}
