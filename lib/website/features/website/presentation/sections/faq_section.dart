import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/reveal_on_scroll.dart';
import '../widgets/site_section_frame.dart';

/// Frequently-asked questions — the objections a sceptical tradie raises
/// before they download. Accessible disclosure: each row is a button that
/// reports its expanded state, and the open/close motion is suppressed under
/// reduced-motion.
class FaqSection extends StatelessWidget {
  const FaqSection({super.key});

  static const _faqs = <_Faq>[
    _Faq(
      'What does it cost?',
      'Tradies download the app and apply for jobs free, forever — no '
          'subscription, no premium tier, no cut of your pay. Builders pay '
          'a flat \$10 a week. Cancel any time from inside the app.',
    ),
    _Faq(
      'Why \$10 a week for builders?',
      'Lead-buying platforms charge \$30–80 per lead and sell the same lead '
          'to three or four rivals. \$10/week covers the cost of running '
          'the licence + ABN checks and the in-app messaging, with no per-'
          'lead fee and no surprise upsells. When the CRM ships later this '
          'year, the second tier will be available at a higher weekly price.',
    ),
    _Faq(
      'How are trades verified?',
      'Trades register with their licence number, which we cross-check '
          'against the national register before they can pick up work. '
          'Builders verify an ABN. Anonymous accounts do not exist on Jobdun.',
    ),
    _Faq(
      'Which areas are you in?',
      "We're launching across Australia's capital cities first, then regional "
          'centres. Set the suburb you work out of and the feed shows the jobs '
          'near you.',
    ),
    _Faq(
      'Is it for builders or for trades?',
      'Both. Builders post jobs and manage applicants; trades and crews '
          'browse, quote, and apply. One app, two sides of the same site.',
    ),
    _Faq(
      'When can I download it?',
      'The app is rolling out on iOS and Android in our AU launch markets. '
          'The store links land at the bottom of this page the moment they go '
          'live.',
    ),
    _Faq(
      'How do I delete my data?',
      'Any time — from inside the app or from the website. See the privacy '
          'policy and the delete-account page linked in the footer below.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        maxWidth: 820,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RevealOnScroll(
              child: Semantics(
                header: true,
                child: Text(
                  'Questions, answered straight.',
                  style: tt.headlineLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),
            const Gap(32),
            Container(height: 1, color: c.border),
            for (final faq in _faqs) _FaqItem(faq: faq),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.faq});

  final _Faq faq;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final motion = reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 220);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          expanded: _open,
          child: InkWell(
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.faq.q,
                      style: tt.titleLarge!.copyWith(
                        color: c.text1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Gap(16),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: motion,
                    child: Icon(
                      AppIcons.chevronDown,
                      size: 20,
                      color: c.action,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 22, right: 36),
            child: Text(
              widget.faq.a,
              style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.6),
            ),
          ),
          crossFadeState: _open
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: motion,
          sizeCurve: Curves.easeOut,
        ),
        Container(height: 1, color: c.border),
      ],
    );
  }
}

class _Faq {
  const _Faq(this.q, this.a);
  final String q;
  final String a;
}
