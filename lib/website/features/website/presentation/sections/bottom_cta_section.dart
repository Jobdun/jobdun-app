import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/site_section_frame.dart';

/// The final CTA. Single column, no header text, no body paragraph.
/// The brand mark + the play-twist tagline + the headline + two store
/// buttons are the whole section. Minimal, declarative, in the FTUE
/// voice. The "JobDun" capitalisation in the tagline is intentional:
/// it highlights the suffix that rhymes with "done" and lands the
/// play on "get the job done" once and only once on the entire site.
class BottomCtaSection extends StatelessWidget {
  const BottomCtaSection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 128),
      child: SiteSectionFrame(
        maxWidth: 720,
        child: Column(
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: JobdunLogo(variant: LogoVariant.badge),
            ),
            const Gap(28),
            // Play-twist tagline: "Everything you need to get the
            // JobDun." Brand voice stays "Jobdun" everywhere else; the
            // capital D here is a deliberate one-off that earns the play
            // on "get the job done".
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: tt.titleMedium!.copyWith(
                  color: c.text2,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.4,
                ),
                children: const [
                  TextSpan(text: 'Everything you need to get the '),
                  TextSpan(
                    text: 'Job',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(
                    text: 'Dun',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  TextSpan(text: '.'),
                ],
              ),
            ),
            const Gap(20),
            Text(
              'Ready when you are.',
              textAlign: TextAlign.center,
              style: tt.displaySmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
            const Gap(24),
            Text(
              'iOS  ·  Android  ·  AU launch markets only',
              textAlign: TextAlign.center,
              style: tt.bodyMedium!.copyWith(
                color: c.text2,
                letterSpacing: 1.2,
              ),
            ),
            const Gap(16),
            // Store badges. Wired to no-op until the apps are published;
            // the listings go live in our AU launch markets first.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 16,
              runSpacing: 16,
              children: const [
                _StoreButton(
                  icon: AppIcons.appleLogo,
                  topLine: 'Download on the',
                  bottomLine: 'App Store',
                ),
                _StoreButton(
                  icon: AppIcons.googlePlayLogo,
                  topLine: 'Get it on',
                  bottomLine: 'Google Play',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreButton extends StatelessWidget {
  const _StoreButton({
    required this.icon,
    required this.topLine,
    required this.bottomLine,
  });

  final IconData icon;
  final String topLine;
  final String bottomLine;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Tooltip(
      message: 'Coming soon: $bottomLine',
      child: Material(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: InkWell(
          onTap: () {},
          borderRadius: BorderRadius.circular(AppRadius.btn.r),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 26, color: c.text1),
                const Gap(12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topLine,
                      style: tt.labelSmall!.copyWith(color: c.text2),
                    ),
                    Text(
                      bottomLine,
                      style: tt.titleMedium!.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
