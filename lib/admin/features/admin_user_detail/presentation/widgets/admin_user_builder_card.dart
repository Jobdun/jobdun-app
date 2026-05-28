import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../domain/entities/admin_builder_profile.dart';
import 'admin_user_kv_row.dart';

/// Builder-specific profile fields card.
class AdminUserBuilderCard extends StatelessWidget {
  const AdminUserBuilderCard({super.key, required this.profile});

  final AdminBuilderProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BUILDER PROFILE',
            style: GoogleFonts.oswald(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: c.text3,
            ),
          ),
          const Gap(12),
          if (profile.companyName != null)
            AdminUserKvRow(label: 'Company', value: profile.companyName!),
          if (profile.abn != null)
            AdminUserKvRow(label: 'ABN', value: profile.abn!),
          if (profile.contactName != null)
            AdminUserKvRow(label: 'Contact Name', value: profile.contactName!),
          if (profile.contactPhone != null)
            AdminUserKvRow(
              label: 'Contact Phone',
              value: profile.contactPhone!,
            ),
          if (profile.yearsInBusiness != null)
            AdminUserKvRow(
              label: 'Years in Business',
              value: '${profile.yearsInBusiness}',
            ),
          if (_hasLocation)
            AdminUserKvRow(label: 'Service Area', value: _locationString),
          if (profile.website != null)
            AdminUserKvRow(
              label: 'Website',
              valueWidget: GestureDetector(
                onTap: () => launchUrl(Uri.parse(profile.website!)),
                child: Text(
                  profile.website!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.openSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.action,
                    decoration: TextDecoration.underline,
                    decorationColor: c.action,
                  ),
                ),
              ),
            ),
          if (profile.description != null)
            AdminUserKvRow(label: 'Description', value: profile.description!),
          if (profile.about != null)
            AdminUserKvRow(label: 'About', value: profile.about!),
        ],
      ),
    );
  }

  bool get _hasLocation =>
      profile.serviceSuburb != null ||
      profile.serviceState != null ||
      profile.servicePostcode != null;

  String get _locationString => [
    profile.serviceSuburb,
    profile.serviceState,
    profile.servicePostcode,
  ].where((v) => v != null && v.isNotEmpty).join(', ');
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}
