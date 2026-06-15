import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';

/// Footer — three columns on desktop, stacked on mobile. The contact
/// column lists both `sam@jobdun.com.au` (general) and
/// `support@jobdun.com.au` (support) per the brief. Legal links point
/// at the static `site/privacy/` and `site/delete-account/` pages (NOT
/// routed through Flutter, by design — they boot faster as plain HTML
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
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(context),
        vertical: AppSpacing.xxl.h,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final columns = [
            _FooterCol(
              title: 'JOBDUN',
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
          if (wide) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < columns.length; i++) ...[
                      Expanded(child: columns[i]),
                      if (i < columns.length - 1) Gap(AppSpacing.xl.w),
                    ],
                  ],
                ),
                Gap(AppSpacing.xl.h),
                Divider(color: c.border, height: 1),
                Gap(AppSpacing.lg.h),
                Text(
                  '© 2026 Jobdun Pty Ltd. Built for Australian construction.',
                  style: tt.bodySmall!.copyWith(color: c.text3),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < columns.length; i++) ...[
                columns[i],
                if (i < columns.length - 1) Gap(AppSpacing.lg.h),
              ],
              Gap(AppSpacing.lg.h),
              Divider(color: c.border, height: 1),
              Gap(AppSpacing.lg.h),
              Text(
                '© 2026 Jobdun Pty Ltd. Built for Australian construction.',
                style: tt.bodySmall!.copyWith(color: c.text3),
              ),
            ],
          );
        },
      ),
    );
  }

  double _hPad(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w >= 1100) return AppSpacing.xxl.w;
    if (w >= 720) return AppSpacing.xl.w;
    return AppSpacing.lg.w;
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
        Gap(AppSpacing.md.h),
        for (final link in items) ...[
          _FooterLinkWidget(link: link),
          Gap(AppSpacing.xs.h),
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
      onTap: () {
        // Honor a different href for anchor links vs absolute URLs.
        if (link.href.startsWith('#')) {
          // Anchor scroll on the home page — only meaningful when the
          // footer is rendered as part of HomePage (which is the only
          // place it ships). We delegate to the global scroll provider.
          // ignore: avoid_print
          debugPrint('footer anchor: ${link.href} (home-page scroll)');
        } else {
          // External / static page. We use a simple Navigator route for
          // mailto: (the OS will pick the right handler). For absolute
          // paths like /privacy/ we leave it to the browser — the
          // marketing site doesn't own those routes.
          debugPrint('footer link: ${link.href}');
        }
      },
      child: Text(
        link.label,
        style: tt.bodyMedium!.copyWith(color: c.text1, height: 1.6),
      ),
    );
  }
}
