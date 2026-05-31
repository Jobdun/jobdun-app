import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../providers/admin_verifications_provider.dart';

/// Inline document preview for the review sheet. Resolves a short-lived signed
/// URL, renders a 320px thumbnail, and — on tap — opens a full-screen,
/// pinch/scroll-zoomable [PhotoView]. The whole point of review is reading a
/// licence number off a photo, so zoom is the core affordance, not a flourish.
///
/// Split out of `admin_verification_review_sheet.dart` to keep that file under
/// the 500-LOC ceiling.
class AdminVerificationDocViewer extends ConsumerWidget {
  const AdminVerificationDocViewer({super.key, required this.filePath});

  final String filePath;

  static const _heroTag = 'admin-verification-document';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return FutureBuilder<String>(
      future: ref.read(adminVerificationsProvider.notifier).signedUrl(filePath),
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return Container(
            height: 280,
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                "Couldn't load file:\n${snap.error}",
                textAlign: TextAlign.center,
                style: AdminText.meta(c.urgent),
              ),
            ),
          );
        }
        final url = snap.data!;
        return Stack(
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openFullscreen(context, url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Hero(
                    tag: _heroTag,
                    child: Image.network(
                      url,
                      height: 320,
                      width: double.infinity,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Container(
                        height: 120,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        color: c.background,
                        child: Text(
                          'File is not a viewable image. Open the URL directly:\n$url',
                          style: AdminText.caption(c.text2),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: c.background.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, size: 14, color: c.text1),
                      const Gap(4),
                      Text('TAP TO ZOOM', style: AdminText.eyebrow(c.text1)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openFullscreen(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => _FullscreenDocViewer(url: url, heroTag: _heroTag),
    );
  }
}

/// Full-screen, pinch/scroll-zoomable document viewer opened from the inline
/// thumbnail. Real inspection happens here via [PhotoView].
class _FullscreenDocViewer extends StatelessWidget {
  const _FullscreenDocViewer({required this.url, required this.heroTag});

  final String url;
  final String heroTag;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: PhotoView(
              imageProvider: NetworkImage(url),
              backgroundDecoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 4,
              heroAttributes: PhotoViewHeroAttributes(tag: heroTag),
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  'File is not a viewable image.',
                  style: AdminText.body(c.text1),
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Material(
              color: c.surface,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: c.text1),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
