import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// Centred hero for the site's sub-pages (For Builders, For Crews, Pricing,
/// Contact). Distinct from the home page's split hero so the sections don't all
/// read as one template: a small orange eyebrow, a large title, a one-line
/// subtitle, and an optional CTA row.
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.ctas = const [],
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final List<Widget> ctas;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.background,
      padding: EdgeInsets.only(
        top: (AppSpacing.xxl * 2.6).h,
        bottom: AppSpacing.xxl.h,
      ),
      child: SiteSectionFrame(
        maxWidth: 860,
        child: RevealOnScroll(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                eyebrow.toUpperCase(),
                textAlign: TextAlign.center,
                style: tt.labelMedium!.copyWith(
                  color: c.actionInk,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Gap(16),
              Semantics(
                header: true,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: tt.displaySmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    height: 1.08,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Gap(20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
                ),
              ),
              if (ctas.isNotEmpty) ...[
                const Gap(32),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: ctas,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
