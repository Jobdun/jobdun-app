import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';
import '../widgets/site_section_frame.dart';
import '../widgets/social_links.dart';

/// Footer: three columns on desktop, stacked on mobile. The contact
/// column lists both `sam@jobdun.com.au` (general) and
/// `support@jobdun.com.au` (support) per the brief. Legal links point
/// at the static `site/privacy/` and `site/delete-account/` pages (NOT
/// routed through Flutter, by design. They boot faster as plain HTML
/// and the marketing site has no need to own them).
class SiteFooter extends StatelessWidget {
  const SiteFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.only(top: 64, bottom: 64),
      child: SiteSectionFrame(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 720;
            final columns = [
              _FooterCol(
                title: 'LEGAL',
                items: [
                  _FooterLink('Privacy policy', '/privacy/'),
                  _FooterLink('Delete your account', '/delete-account/'),
                ],
              ),
              _FooterCol(
                title: 'CONTACT',
                items: const [
                  _FooterLink('sam@jobdun.com.au', 'mailto:sam@jobdun.com.au'),
                  _FooterLink(
                    'support@jobdun.com.au',
                    'mailto:support@jobdun.com.au',
                  ),
                ],
              ),
              _FooterCol(
                title: 'GET THE APP',
                items: const [
                  _FooterLink('Post a job', '#hiring'),
                  _FooterLink('Find work', '#crews'),
                ],
              ),
            ];
            final cols = wide
                ? <Widget>[
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < columns.length; i++) ...[
                            Expanded(child: columns[i]),
                            if (i < columns.length - 1)
                              const SizedBox(width: 32),
                          ],
                        ],
                      ),
                    ),
                    const Gap(32),
                    Container(height: 1, color: c.border),
                    const Gap(24),
                    Text(
                      '© 2026 Jobdun Pty Ltd. Built for Australian construction.',
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ]
                : <Widget>[
                    for (var i = 0; i < columns.length; i++) ...[
                      columns[i],
                      if (i < columns.length - 1) const Gap(16),
                    ],
                    const Gap(16),
                    Container(height: 1, color: c.border),
                    const Gap(16),
                    Text(
                      '© 2026 Jobdun Pty Ltd. Built for Australian construction.',
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const JobdunLogo(variant: LogoVariant.mark, height: 34),
                const Gap(12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    'The verified workforce platform for Australian '
                    'construction trades.',
                    style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.5),
                  ),
                ),
                const Gap(20),
                const SocialLinks(iconSize: 20),
                const Gap(40),
                ...cols,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FooterCol extends StatelessWidget {
  const _FooterCol({required this.title, required this.items});

  final String title;
  final List<_FooterLink> items;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: tt.labelMedium!.copyWith(
            color: c.text3,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Gap(16),
        for (final link in items) ...[
          _FooterLinkWidget(link: link),
          const Gap(4),
        ],
      ],
    );
  }
}

class _FooterLink {
  const _FooterLink(this.label, this.href);
  final String label;
  final String href;
}

class _FooterLinkWidget extends StatelessWidget {
  const _FooterLinkWidget({required this.link});

  final _FooterLink link;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(link.href);
        // Anchors + mailto: open in a new tab; absolute paths open
        // in the same tab. Falls through silently if `url_launcher`
        // can't open (offline build, unsupported scheme). The link
        // still renders and is hover-focusable, so accessibility
        // isn't broken.
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Text(
        link.label,
        style: tt.bodyMedium!.copyWith(color: c.text1, height: 1.6),
      ),
    );
  }
}
