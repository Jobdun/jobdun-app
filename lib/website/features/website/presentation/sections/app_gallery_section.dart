import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../widgets/orange_rule.dart';
import '../widgets/phone_frame.dart';
import '../widgets/site_section_frame.dart';

/// "A wall of the actual app" — three phone screenshots arranged
/// side-by-side on the page's lower half. This is the visual
/// moment where the marketing site stops talking about the product
/// and shows it. Each phone carries a tiny caption strip at the
/// bottom (matching the screenshot's frame) so the reader doesn't
/// have to guess what they're looking at.
///
/// Composition on the section background:
///   1. An orange rule centred above the gallery — the second hard
///      rhythm break on the page (the first is the editorial /
///      values transition).
///   2. A short headline centred above the phones, no eyebrow
///      (we said no to the "tiny-text → big-text" formula).
///   3. Three phones, each tilted at a different angle, with a
///      caption strip below each.
///   4. An orange rule centred below.
///
/// Phones are 9:19.5 aspect — modern flagship proportion — and
/// stack on mobile (<720). On web, 320-px wide, with a 16-px gap.
class AppGallerySection extends StatelessWidget {
  const AppGallerySection({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final stacked = w < 960;

    const phones = [
      _PhoneEntry(
        asset: 'assets/website/screenshots/ftue-splash.png',
        caption: 'Verified. Every time.',
        tilt: -0.05,
      ),
      _PhoneEntry(
        asset: 'assets/website/screenshots/aussie-site.jpg',
        caption: 'Built for the site.',
        tilt: 0.04,
      ),
      _PhoneEntry(
        asset: 'assets/website/screenshots/create-account.png',
        caption: 'Three taps. You\'re in.',
        tilt: -0.03,
      ),
    ];

    return Container(
      width: double.infinity,
      color: c.background,
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top orange rule
            const Padding(
              padding: EdgeInsets.only(bottom: 32),
              child: Center(child: OrangeRule(width: 48, thickness: 3)),
            ),
            Text(
              'The app.',
              textAlign: TextAlign.center,
              style: tt.displaySmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const Gap(8),
            Text(
              'Built for tradies. Built for builders. Built for the site.',
              textAlign: TextAlign.center,
              style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.5),
            ),
            const Gap(64),
            if (stacked)
              Column(
                children: [
                  for (var i = 0; i < phones.length; i++) ...[
                    _PhoneWithCaption(phone: phones[i], width: 280),
                    if (i < phones.length - 1) const Gap(48),
                  ],
                ],
              )
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (var i = 0; i < phones.length; i++) ...[
                      Expanded(child: _PhoneWithCaption(phone: phones[i])),
                      if (i < phones.length - 1) const Gap(24),
                    ],
                  ],
                ),
              ),
            const Gap(48),
            // Bottom orange rule — closes the gallery with the same
            // beat the top one opened with.
            const Center(child: OrangeRule(width: 48, thickness: 3)),
          ],
        ),
      ),
    );
  }
}

class _PhoneEntry {
  const _PhoneEntry({
    required this.asset,
    required this.caption,
    required this.tilt,
  });
  final String asset;
  final String caption;
  final double tilt;
}

class _PhoneWithCaption extends StatelessWidget {
  const _PhoneWithCaption({required this.phone, this.width = 320});

  final _PhoneEntry phone;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: PhoneFrame(asset: phone.asset, tilt: phone.tilt, width: width),
        ),
        const Gap(20),
        Text(
          phone.caption,
          textAlign: TextAlign.center,
          style: tt.titleLarge!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
