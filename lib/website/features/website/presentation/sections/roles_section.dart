import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/breakpoints.dart';
import '../../../../../core/design/colors.dart';
import '../widgets/phone_frame.dart';
import '../widgets/site_section_frame.dart';

/// Two role phones — on web, a centred 2-up. On mobile, a horizontal
/// PageView so the user can swipe between roles (the user does NOT
/// want a stacked column on a phone — they explicitly asked for a
/// swipeable carousel).
///
/// CTAs live in the bottom-CTA section; this section is purely
/// "here is what the app looks like for each role".
class RolesSection extends StatefulWidget {
  const RolesSection({super.key});

  @override
  State<RolesSection> createState() => _RolesSectionState();
}

class _RolesSectionState extends State<RolesSection> {
  // Real device captures — one per role, showing the actual
  // builder / crew experience. The builder side shows the home
  // with a new applicant hero ("NEXT: 1 NEW APPLICANT") — the
  // value moment for builders. The crew side shows FTUE page 2
  // ("JOBS NEAR YOU. APPLY IN THREE TAPS.") — the tradie's
  // promise: local jobs, one-tap apply.
  static const _items = <_RoleItem>[
    _RoleItem(
      asset: 'assets/website/screenshots/17_builder_home_with_applicant.webp',
      caption: 'For builders hiring trades.',
    ),
    _RoleItem(
      asset: 'assets/website/screenshots/ftue-page-2.webp',
      caption: 'For crews looking for work.',
    ),
  ];

  final _pageController = PageController(viewportFraction: 0.78);
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(() {
      setState(() => _page = _pageController.page ?? 0);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final w = MediaQuery.sizeOf(context).width;
    final carousel = w < Bp.tablet;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (carousel)
              _Carousel(controller: _pageController, items: _items)
            else
              _TwoUp(items: _items),
            if (carousel) ...[
              Gap(AppSpacing.lg.h),
              _Dots(
                count: _items.length,
                page: _page,
                controller: _pageController,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleItem {
  const _RoleItem({required this.asset, required this.caption});
  final String asset;
  final String caption;
}

class _TwoUp extends StatelessWidget {
  const _TwoUp({required this.items});
  final List<_RoleItem> items;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 48),
            Expanded(child: _RoleCard(item: items[i])),
          ],
        ],
      ),
    );
  }
}

class _Carousel extends StatelessWidget {
  const _Carousel({required this.controller, required this.items});
  final PageController controller;
  final List<_RoleItem> items;

  @override
  Widget build(BuildContext context) {
    // SizedBox gives the PageView a finite height; otherwise the
    // unconstrained PageView (inside a Column with mainAxisSize.min)
    // throws on layout. Phone width 320 × 9:19.5 aspect ≈ 696 +
    // caption + breathing room.
    const phoneH = 696.0;
    return SizedBox(
      height: phoneH + 96, // phone + caption + breathing room
      child: PageView.builder(
        controller: controller,
        itemCount: items.length,
        physics: const PageScrollPhysics(),
        padEnds: false,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _RoleCard(item: items[i]),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({
    required this.count,
    required this.page,
    required this.controller,
  });
  final int count;
  final double page;
  final PageController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final active = (page - i).abs() < 0.5;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active ? c.action : c.borderStrong,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        );
      }),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.item});
  final _RoleItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Center(
          child: PhoneFrame(asset: item.asset, width: 220, maxHeight: 520),
        ),
        const Gap(24),
        Text(
          item.caption,
          textAlign: TextAlign.center,
          style: tt.headlineSmall!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
