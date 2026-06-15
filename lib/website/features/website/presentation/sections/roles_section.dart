import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

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
  static const _items = <_RoleItem>[
    _RoleItem(
      asset: 'assets/website/screenshots/create-account.png',
      caption: 'For builders hiring trades.',
      tilt: -0.03,
    ),
    _RoleItem(
      asset: 'assets/website/screenshots/ftue-splash.png',
      caption: 'For crews looking for work.',
      tilt: 0.04,
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
    final carousel = w < 720;

    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsets.symmetric(vertical: 96),
      child: SiteSectionFrame(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (carousel) _Carousel(controller: _pageController, items: _items)
            else _TwoUp(items: _items),
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
  const _RoleItem({required this.asset, required this.caption, required this.tilt});
  final String asset;
  final String caption;
  final double tilt;
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
    // throws on layout. Height = phone maxHeight + caption gap.
    const phoneH = 560.0;
    return SizedBox(
      height: phoneH + 80, // phone + caption + breathing room
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
  const _Dots({required this.count, required this.page, required this.controller});
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
          child: PhoneFrame(
            asset: item.asset,
            tilt: item.tilt,
            maxHeight: 560,
          ),
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
