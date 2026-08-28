import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../widgets/ftue_overlay_card.dart';
import '../widgets/ftue_slide.dart';

/// Slide 3 — "Built for Aussie sites." Closes on the local claim.
///
/// The three cards down the left (Figma nodes 60:187, 60:192, 60:211) each
/// carry a glyph. Two map cleanly onto Phosphor; the Australia outline has no
/// Phosphor equivalent, so it ships as the exported Figma vector
/// (`lib/core/assets/icon-australia.svg`) tinted to `c.actionInk`.
class SlideThreeAction extends StatelessWidget {
  const SlideThreeAction({
    super.key,
    required this.controller,
    required this.slideCount,
  });

  static const heroAsset = 'assets/images/ftue/slide_3_aussie_site.webp';
  static const _australiaAsset = 'lib/core/assets/icon-australia.svg';

  final PageController controller;
  final int slideCount;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return FtueSlide(
      assetPath: heroAsset,
      slideIndex: 2,
      semanticLabel: 'A builder on an Australian residential construction site',
      lead: 'BUILT FOR',
      accent: 'AUSSIE SITES.',
      controller: controller,
      slideCount: slideCount,
      overlays: [
        FtueOverlay(
          left: 27 / 393,
          top: 119 / 567,
          child: FtueOverlayCard.feature(
            label: 'Made in Australia',
            child: SvgPicture.asset(
              _australiaAsset,
              width: 40.r,
              height: 40.r,
              colorFilter: ColorFilter.mode(c.actionInk, BlendMode.srcIn),
            ),
          ),
        ),
        const FtueOverlay(
          left: 27 / 393,
          top: 233 / 567,
          child: FtueOverlayCard.feature(
            label: 'For Builders and Crews',
            icon: AppIcons.peopleGroupFilled,
          ),
        ),
        const FtueOverlay(
          left: 27 / 393,
          top: 347 / 567,
          child: FtueOverlayCard.feature(
            label: 'Built for sites',
            icon: AppIcons.buildingFilled,
          ),
        ),
      ],
    );
  }
}
