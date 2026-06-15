import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';

/// Follow row — Instagram / Facebook / LinkedIn / TikTok. Shared by the footer
/// and the contact page. Each is a focusable, tooltipped icon button that opens
/// the channel in a new tab. URLs are the public Jobdun handles (swap if the
/// real handles differ).
class SocialLinks extends StatelessWidget {
  const SocialLinks({super.key, this.iconSize = 22});

  final double iconSize;

  static const _socials = <({IconData icon, String label, String url})>[
    (
      icon: AppIcons.instagram,
      label: 'Jobdun on Instagram',
      url: 'https://instagram.com/jobdun',
    ),
    (
      icon: AppIcons.facebook,
      label: 'Jobdun on Facebook',
      url: 'https://facebook.com/jobdun',
    ),
    (
      icon: AppIcons.linkedin,
      label: 'Jobdun on LinkedIn',
      url: 'https://linkedin.com/company/jobdun',
    ),
    (
      icon: AppIcons.tiktok,
      label: 'Jobdun on TikTok',
      url: 'https://tiktok.com/@jobdun',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in _socials)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _SocialIcon(
              icon: s.icon,
              label: s.label,
              url: s.url,
              iconSize: iconSize,
            ),
          ),
      ],
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.icon,
    required this.label,
    required this.url,
    required this.iconSize,
  });

  final IconData icon;
  final String label;
  final String url;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Tooltip(
      message: label,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: c.surfaceRaised,
          shape: CircleBorder(side: BorderSide(color: c.border)),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            onPressed: () async {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
            iconSize: iconSize,
            color: c.text2,
            tooltip: label,
            icon: Icon(icon),
          ),
        ),
      ),
    );
  }
}
