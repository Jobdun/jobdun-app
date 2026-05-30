import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../data/state_licence_registers.dart';

/// One-click deep link to the correct state/territory building-licence register,
/// shown on the admin review sheet for a trade licence. Australia has no
/// national register, so the admin verifies each licence on the relevant state
/// regulator's public search page — this removes the "which register again?"
/// friction and the risk of checking the wrong one. Renders nothing for an
/// unknown/unset state.
class AdminOfficialRegisterLink extends StatelessWidget {
  const AdminOfficialRegisterLink({
    super.key,
    required this.state,
    this.licenceNumber,
  });

  final String? state;
  final String? licenceNumber;

  @override
  Widget build(BuildContext context) {
    final reg = licenceRegisterFor(state);
    if (reg == null) return const SizedBox.shrink();
    final c = context.c;
    final number = licenceNumber?.trim();
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(reg.url), mode: LaunchMode.externalApplication),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.action.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.action.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.open_in_new, size: 16, color: c.action),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CHECK ON ${reg.regulator.toUpperCase()}',
                    style: GoogleFonts.openSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: c.action,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${reg.state} official register · search by ${reg.searchBy}'
                    '${number != null && number.isNotEmpty ? ' · $number' : ''}',
                    style: GoogleFonts.openSans(fontSize: 11, color: c.text3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
