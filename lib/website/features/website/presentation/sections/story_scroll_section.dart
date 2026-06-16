import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../widgets/fullscreen_phone_modal.dart';
import '../widgets/orange_rule.dart';
import '../widgets/phone_frame.dart';
import '../widgets/site_section_frame.dart';

/// A real carousel of three real-device product captures. One slide
/// in view at a time, next slide peeking from the right. Tap a
/// phone to expand it fullscreen via [FullscreenPhoneModal].
///
/// Layout: `padEnds: true` centres the active page; fixed-height
/// phone + caption blocks keep the three cards visually identical
/// (same phone position, same "TAP TO EXPAND" position, same
/// caption baseline). `ClampingScrollPhysics` makes drag work on
/// web (the default `PageScrollPhysics` is iOS-flavoured).
class StoryScrollSection extends StatefulWidget {
  const StoryScrollSection({super.key});

  @override
  State<StoryScrollSection> createState() => _StoryScrollSectionState();
}

class _StoryScrollSectionState extends State<StoryScrollSection> {
  // Initial viewportFraction; rebind on width change so mobile
  // (85% of viewport) and desktop (30% of viewport) both work.
  PageController _pageController = PageController(viewportFraction: 0.3);
  double? _lastWidth;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    setState(() => _page = _pageController.page ?? 0);
  }

  void _rebindController(double width) {
    final isMobile = width < 720;
    final newFraction = isMobile ? 0.85 : 0.30;
    if (_lastWidth == null) {
      _lastWidth = width;
      // Initial fraction may differ from 0.3; rebind before first paint.
      _pageController.dispose();
      _pageController = PageController(viewportFraction: newFraction);
      _pageController.addListener(_onPageChanged);
      return;
    }
    if ((_lastWidth! < 720) == isMobile) return;
    _lastWidth = width;
    final currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? 0)
        : 0;
    _pageController.removeListener(_onPageChanged);
    _pageController.dispose();
    _pageController = PageController(
      viewportFraction: newFraction,
      initialPage: currentPage,
    );
    _pageController.addListener(_onPageChanged);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _expand(_StoryBeat beat) {
    HapticFeedback.selectionClick();
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xCC0A1220),
      builder: (_) =>
          FullscreenPhoneModal(asset: beat.asset, semanticLabel: beat.eyebrow),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final w = MediaQuery.sizeOf(context).width;
    final isMobile = w < 720;
    // Layout by breakpoint:
    //   mobile  (<720):  viewportFraction 0.85 → page is 85% of
    //                   viewport. Card fills the page. Phone is
    //                   ~55% of the card.
    //   tablet/desktop (≥720): viewportFraction 0.30, cardMaxWidth
    //                   300/360. Phone is ~52% of the card.
    final cardMaxWidth = isMobile ? w * 0.85 - 24 : (w < 1100 ? 300.0 : 360.0);
    final phoneWidth = cardMaxWidth * (isMobile ? 0.55 : 0.52);
    // Rebind the PageController's viewportFraction when the
    // breakpoint changes. On first build the controller is created
    // with the mobile or desktop fraction directly.
    _rebindController(w);

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: OrangeRule(width: 64, thickness: 4)),
            const Gap(24),
            Text(
              'See it in action.',
              style: tt.displaySmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                height: 1.05,
                letterSpacing: -0.5,
              ),
            ),
            const Gap(12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                'Three captures from a real device. Tap a phone for the '
                'full screen — the same flow your crew runs through on day one.',
                style: tt.bodyLarge!.copyWith(color: c.text2, height: 1.55),
              ),
            ),
            const Gap(56),
            // Fixed height: phone (width×19.5/9) + tap-hint (18) +
            // gap (16) + caption (140) + card padding (44). All
            // three cards have this same height.
            SizedBox(
              height: phoneWidth * (19.5 / 9) + 220,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _steps.length,
                physics: const ClampingScrollPhysics(),
                padEnds: true,
                itemBuilder: (context, i) {
                  final beat = _steps[i];
                  final isActive = (i - _page).abs() < 0.5;
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 220),
                    opacity: isActive ? 1.0 : 0.7,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardMaxWidth),
                        child: _Slide(
                          beat: beat,
                          phoneWidth: phoneWidth,
                          onPhoneTap: () => _expand(beat),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Gap(16),
            Center(
              child: _Dots(
                count: _steps.length,
                page: _page,
                onDot: (i) => _pageController.animateToPage(
                  i,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
            const Gap(48),
            const Center(child: OrangeRule(width: 48, thickness: 3)),
          ],
        ),
      ),
    );
  }

  static const _steps = <_StoryBeat>[
    _StoryBeat(
      number: '01',
      eyebrow: 'Sign in',
      headline: 'One account. Two sides.',
      body: 'Email, Google, or Apple. Switch sides any time.',
      asset: 'assets/website/screenshots/login.png',
    ),
    _StoryBeat(
      number: '02',
      eyebrow: 'Post the job',
      headline: 'Five steps. Twenty seconds.',
      body: 'Trade filters who sees the listing. Verified crews first.',
      asset: 'assets/website/screenshots/post-job-wizard.png',
    ),
    _StoryBeat(
      number: '03',
      eyebrow: 'Hire the tradie',
      headline: "You're connected.",
      body: 'One tap. Rate is locked. Message opens the second it lands.',
      asset: 'assets/website/screenshots/hire-celebration.png',
    ),
  ];
}

class _StoryBeat {
  const _StoryBeat({
    required this.number,
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.asset,
  });
  final String number;
  final String eyebrow;
  final String headline;
  final String body;
  final String asset;
}

class _Slide extends StatelessWidget {
  const _Slide({
    required this.beat,
    required this.phoneWidth,
    required this.onPhoneTap,
  });
  final _StoryBeat beat;
  final double phoneWidth;
  final VoidCallback onPhoneTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Every card has the same internal structure: fixed phone
    // height, fixed gap, fixed caption block. Fixed heights mean
    // the visual layout is identical across all three cards.
    final phoneHeight = phoneWidth * (19.5 / 9);
    const gap = 16.0;
    const captionHeight = 140.0;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phone: fixed height so all 3 cards have the phone at the
          // same vertical position. The phone is a tappable area
          // (opens the modal); the "TAP TO EXPAND" hint lives
          // *inside* the phone widget so the hover state matches the
          // tappable region.
          _TappablePhone(
            asset: beat.asset,
            semanticLabel: beat.eyebrow,
            width: phoneWidth,
            fixedHeight: phoneHeight,
            onTap: onPhoneTap,
          ),
          SizedBox(height: gap),
          SizedBox(
            height: captionHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      beat.number,
                      style: tt.displaySmall!.copyWith(
                        color: c.action,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const Gap(12),
                    Container(width: 24, height: 2, color: c.action),
                    const Gap(10),
                    Text(
                      beat.eyebrow.toUpperCase(),
                      style: tt.labelLarge!.copyWith(
                        color: c.action,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                Text(
                  beat.headline,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const Gap(8),
                Text(
                  beat.body,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TappablePhone extends StatefulWidget {
  const _TappablePhone({
    required this.asset,
    required this.semanticLabel,
    required this.width,
    required this.fixedHeight,
    required this.onTap,
  });
  final String asset;
  final String semanticLabel;
  final double width;
  // The phone + hint live inside a fixed-height container so the
  // visual top of the phone is identical across all three cards.
  final double fixedHeight;
  final VoidCallback onTap;

  @override
  State<_TappablePhone> createState() => _TappablePhoneState();
}

class _TappablePhoneState extends State<_TappablePhone> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final phoneHeight = widget.width * (19.5 / 9);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: widget.fixedHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              // Phone: top-aligned, fixed height.
              SizedBox(
                height: phoneHeight,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  transform: Matrix4.translationValues(
                    0,
                    _hovering ? -4 : 0,
                    0,
                  ),
                  child: PhoneFrame(
                    asset: widget.asset,
                    semanticLabel: widget.semanticLabel,
                    width: widget.width,
                  ),
                ),
              ),
              const Spacer(),
              // Hint: bottom of the fixed container.
              AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _hovering ? 1.0 : 0.55,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(AppIcons.eyeOpen, size: 13),
                    const Gap(6),
                    Text(
                      'TAP TO EXPAND',
                      style: tt.labelLarge!.copyWith(
                        color: c.text2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, required this.onDot});
  final int count;
  final double page;
  final ValueChanged<int> onDot;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = (page - i).abs() < 0.5;
        return GestureDetector(
          onTap: () => onDot(i),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: active ? c.action : c.borderStrong,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      }),
    );
  }
}
