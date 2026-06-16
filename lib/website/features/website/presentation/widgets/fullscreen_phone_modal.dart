import 'package:flutter/material.dart';

import '../../../../../core/theme/app_icons.dart';
import '../../../../app/theme/breakpoints.dart';
import '../widgets/phone_frame.dart';

/// Fullscreen phone modal — opens when a [StoryScrollSection] phone
/// is tapped. The phone is the entire surface: viewport-filling,
/// centered, with the screenshot at the maximum readable size. **No
/// caption** — the caption lives on the in-page carousel card, where
/// the user is reading. The modal is for "look at this screen at
/// 1:1", not for re-reading the copy.
class FullscreenPhoneModal extends StatelessWidget {
  const FullscreenPhoneModal({
    super.key,
    required this.asset,
    required this.semanticLabel,
  });

  final String asset;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    // Phone fits the viewport's shorter axis minus a small margin.
    // On mobile, width drives; on web, height drives.
    final phoneW = mq.width < Bp.tablet
        ? (mq.width - 48).clamp(280.0, 420.0)
        : (mq.height * (9 / 19.5) - 32).clamp(360.0, 540.0);
    return Dialog(
      backgroundColor: const Color(0xFF0A1220),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SizedBox(
        width: mq.width,
        height: mq.height,
        child: Stack(
          children: [
            Center(
              child: PhoneFrame(
                asset: asset,
                semanticLabel: semanticLabel,
                width: phoneW,
                maxHeight: mq.height - 96,
              ),
            ),
            Positioned(
              top: 24,
              right: 24,
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.closeCircle, color: Colors.white),
                  iconSize: 32,
                  tooltip: 'Close',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
