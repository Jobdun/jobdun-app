import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../widgets/admin_scaffold.dart';

/// Stand-in for admin surfaces that are scaffolded in the nav but not yet
/// implemented (Users, Jobs, Audit Log). Mirrors the dashboard's
/// "COMING SOON" card so the empty space stays on-brand.
class AdminPlaceholderPage extends StatelessWidget {
  const AdminPlaceholderPage({
    super.key,
    required this.title,
    required this.icon,
    required this.activeRoute,
    required this.copy,
    this.bullets = const [],
  });

  final String title;
  final IconData icon;
  final String activeRoute;
  final String copy;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return AdminScaffold(
      title: title,
      activeRoute: activeRoute,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 26, color: c.action),
                ),
                const Gap(20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceRaised,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'COMING SOON',
                          style: GoogleFonts.openSans(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: c.text3,
                          ),
                        ),
                      ),
                      const Gap(8),
                      Text(
                        title,
                        style: GoogleFonts.oswald(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: c.text1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Gap(24),
            Text(
              copy,
              style: GoogleFonts.openSans(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.55,
                color: c.text2,
              ),
            ),
            if (bullets.isNotEmpty) ...[
              const Gap(24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLANNED CAPABILITIES',
                      style: GoogleFonts.openSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: c.text3,
                      ),
                    ),
                    const Gap(12),
                    for (final b in bullets) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: c.action,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                          const Gap(12),
                          Expanded(
                            child: Text(
                              b,
                              style: GoogleFonts.openSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                height: 1.55,
                                color: c.text2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Gap(8),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
