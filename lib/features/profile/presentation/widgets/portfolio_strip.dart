import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../providers/profile_provider.dart';

// Horizontal grid of the trade's portfolio_urls + a "+" tile to add more.
// Long-press a thumbnail to remove. image_picker's imageQuality=85 already
// transcodes through the platform encoder — good enough for v1; if storage
// bills get spicy we can layer flutter_image_compress on top later.
class PortfolioStrip extends ConsumerWidget {
  const PortfolioStrip({super.key});

  static const _maxImages = 12;

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (picked == null) return;

    final ok = await ref
        .read(profileControllerProvider.notifier)
        .addPortfolioImage(File(picked.path));

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
            onLongPress: () => _confirmRemove(ctx, ref, url),
          );
        },
      ),
    );
  }
}

class _PortfolioTile extends StatelessWidget {
  const _PortfolioTile({required this.url, required this.onLongPress});

  final String url;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      label: 'Portfolio photo. Long-press to remove.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          child: SizedBox(
            width: 88.h,
            height: 88.h,
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
