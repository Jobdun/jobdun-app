import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';

class AdminTopbar extends StatelessWidget {
  const AdminTopbar({super.key, required this.title, this.trailing});

  final String title;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: c.background,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.oswald(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: c.text1,
              ),
            ),
          ),
          if (trailing != null) ...[const Gap(16), ...trailing!],
        ],
      ),
    );
  }
}
