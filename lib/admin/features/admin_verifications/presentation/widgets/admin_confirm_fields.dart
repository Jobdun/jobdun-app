import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';

/// Admin-confirmed identity fields on the review sheet. The "Confirmed number"
/// is what the reviewer reads off the document image (pre-filled from the
/// user-typed value), so the stored identifier isn't trusted blind (audit A2).
/// For a trade licence we also capture the confirmed trade class (audit A3),
/// which the manual upload path never collects.
class AdminConfirmFields extends StatelessWidget {
  const AdminConfirmFields({
    super.key,
    required this.numberController,
    required this.tradeClassController,
    required this.showTradeClass,
  });

  final TextEditingController numberController;
  final TextEditingController tradeClassController;
  final bool showTradeClass;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CONFIRM WHAT YOU SAW ON THE DOCUMENT',
          style: GoogleFonts.openSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: c.text3,
          ),
        ),
        const Gap(8),
        TextField(
          controller: numberController,
          decoration: InputDecoration(
            labelText: 'Confirmed number',
            helperText: 'Edit if it differs from what the user typed.',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: c.background,
          ),
        ),
        if (showTradeClass) ...[
          const Gap(12),
          TextField(
            controller: tradeClassController,
            decoration: InputDecoration(
              labelText: 'Confirmed trade class',
              helperText:
                  'e.g. Carpentry, Electrical — as shown on the licence.',
              border: const OutlineInputBorder(),
              filled: true,
              fillColor: c.background,
            ),
          ),
        ],
      ],
    );
  }
}
