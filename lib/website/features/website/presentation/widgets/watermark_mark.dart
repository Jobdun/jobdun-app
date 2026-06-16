import 'package:flutter/material.dart';

import '../../../../../../core/design/widgets/jobdun_logo.dart';

/// A large hammer-J mark anchored to one corner of a section, used
/// as a visual anchor (not a watermark — opacity is high enough to
/// register as a mark, low enough to never compete with copy).
///
/// Use on editorial / empty sections where the page needs a
/// counterweight to the right-aligned content. The mark is the
/// same `mark-jobdun.svg` shipped in the mobile app, just larger.
class WatermarkMark extends StatelessWidget {
  const WatermarkMark({
    super.key,
    this.size = 360,
    this.opacity = 0.04,
    this.alignment = Alignment.topRight,
    this.tilt = -0.06,
  });

  final double size;
  final double opacity;
  final Alignment alignment;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: FractionalTranslation(
        translation: const Offset(0.18, 0),
        child: IgnorePointer(
          child: Opacity(
            opacity: opacity,
            child: Transform.rotate(
              angle: tilt,
              child: SizedBox(
                width: size,
                height: size,
                child: const JobdunLogo(variant: LogoVariant.mark),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
