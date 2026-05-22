import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/services/image_upload_service.dart';
import '../providers/profile_provider.dart';

// Horizontal grid of the trade's portfolio_urls + a "+" tile to add more.
// Long-press a thumbnail to remove. Tap to open the PhotoView gallery with
// pinch-zoom + horizontal swipe. Uploads pass through ImageUploadService
// (4:3 crop + JPEG compression) so the bucket never receives raw camera
// originals.
class PortfolioStrip extends ConsumerWidget {
  const PortfolioStrip({super.key});

  static const _maxImages = 12;

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    File? file;
    try {
      file = await ImageUploadService.pickCropCompress(
        source: ImageSource.gallery,
        aspect: ImageAspect.portfolio,
      );
    } on UploadGuardException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      return;
    }
    if (file == null) return;

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .addPortfolioImage(file);

    if (!context.mounted) return;
    if (!ok) {
      final c = context.c;
      final tt = Theme.of(context).textTheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Couldn't add photo. Try again.",
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-error snackbar
            ),
          ),
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    String url,
  ) async {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        title: Text(
          'Remove this photo?',
          style: tt.titleMedium!.copyWith(color: c.text1),
        ),
        content: Text(
          "It'll be deleted from your portfolio.",
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: tt.bodyMedium!.copyWith(color: c.text3),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Remove',
              style: tt.bodyMedium!.copyWith(
                color: c.urgent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (yes != true || !context.mounted) return;
    await ref
        .read(profileControllerProvider.notifier)
        .removePortfolioImage(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final urls = ref.watch(
      profileControllerProvider.select(
        (s) => s.tradeProfile?.portfolioUrls ?? const <String>[],
      ),
    );
    final isUploading = ref.watch(
      profileControllerProvider.select((s) => s.isUploadingPortfolio),
    );

    final canAdd = urls.length < _maxImages;

    return SizedBox(
      height: 88.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length + (canAdd ? 1 : 0),
        separatorBuilder: (_, _) => Gap(8.w),
        itemBuilder: (ctx, i) {
          if (canAdd && i == urls.length) {
            return _AddTile(
              isLoading: isUploading,
              onTap: isUploading ? null : () => _pickAndUpload(ctx, ref),
            );
          }
          final url = urls[i];
          return _PortfolioTile(
            url: url,
            onTap: () => _openGallery(ctx, urls, i),
            onLongPress: () => _confirmRemove(ctx, ref, url),
          );
        },
      ),
    );
  }

  void _openGallery(BuildContext context, List<String> urls, int initial) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) =>
            _PortfolioGalleryPage(urls: urls, initialIndex: initial),
      ),
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({
    required this.url,
    required this.onTap,
    required this.onLongPress,
  });

  final String url;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Portfolio photo. Tap to enlarge, long-press to remove.',
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          child: SizedBox(
            width: 88.h,
            height: 88.h,
            child: Hero(
              tag: 'portfolio:$url',
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: c.surfaceRaised),
                errorWidget: (_, _, _) => Container(
                  color: c.surfaceRaised,
                  child: Icon(AppIcons.imageEmpty, color: c.text3, size: 20.r),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Full-screen swipeable gallery for the portfolio strip. Pinch-zoom up to
// 3×, swipe left/right to page between photos. Background fades into the
// brand background colour so the dark theme reads continuous from the
// tile out into the gallery.
class _PortfolioGalleryPage extends StatefulWidget {
  const _PortfolioGalleryPage({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_PortfolioGalleryPage> createState() => _PortfolioGalleryPageState();
}

class _PortfolioGalleryPageState extends State<_PortfolioGalleryPage> {
  late int _index = widget.initialIndex;
  late final PageController _pageController = PageController(
    initialPage: widget.initialIndex,
  );

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: c.text1),
        title: Text(
          '${_index + 1} / ${widget.urls.length}',
          style: tt.labelLarge!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: PhotoViewGallery.builder(
        itemCount: widget.urls.length,
        pageController: _pageController,
        onPageChanged: (i) => setState(() => _index = i),
        backgroundDecoration: BoxDecoration(color: c.background),
        builder: (ctx, i) => PhotoViewGalleryPageOptions(
          imageProvider: CachedNetworkImageProvider(widget.urls[i]),
          heroAttributes: PhotoViewHeroAttributes(
            tag: 'portfolio:${widget.urls[i]}',
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 3,
          errorBuilder: (_, _, _) => Center(
            child: Icon(AppIcons.imageEmpty, color: c.text3, size: 48.r),
          ),
        ),
        loadingBuilder: (_, _) => Center(
          child: SizedBox(
            width: 36.r,
            height: 36.r,
            child: CircularProgressIndicator(color: c.action, strokeWidth: 2),
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.isLoading, required this.onTap});

  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: 'Add portfolio photo',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 88.h,
          height: 88.h,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border, style: BorderStyle.solid),
          ),
          child: isLoading
              ? Center(
                  child: SizedBox(
                    width: 20.r,
                    height: 20.r,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: c.action,
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(AppIcons.add, size: 24.r, color: c.action),
                    Gap(2.h),
                    Text(
                      'ADD',
                      style: tt.labelSmall!.copyWith(
                        color: c.action,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
