import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/theme/app_icons.dart';

/// Avatar header for `/profile/edit`. Pulls double duty as the affordance
/// for editing the avatar AND as the visual confirmation of the current
/// avatar — tap opens the picker sheet, the upload spinner overlays in
/// place. Hero tag matches the profile page's header avatar so the
/// transition flows when that page wires its own Hero in a follow-up.
///
/// State states:
///   - `isUploading` → black overlay + spinner, taps disabled.
///   - `errorMessage != null` → small red "tap to retry" chip below.
///   - `cacheGeneration` → bumped after every successful upload/remove so
///     `CachedNetworkImage` re-fetches even when the storage URL is
///     identical (Supabase replaces the file in place at the same path).
class ProfileEditAvatarHeader extends StatelessWidget {
  const ProfileEditAvatarHeader({
    super.key,
    required this.avatarUrl,
    required this.initials,
    required this.isUploading,
    required this.cacheGeneration,
    required this.errorMessage,
    required this.onTap,
  });

  final String? avatarUrl;
  final String initials;
  final bool isUploading;
  final int cacheGeneration;
  final String? errorMessage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final hasError = errorMessage != null;
    final cacheKey = avatarUrl == null ? null : '$avatarUrl::v$cacheGeneration';

    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Hero(
              tag: 'profile-avatar',
              child: Stack(
                children: [
                  // Re-keying on cacheKey forces a fresh subtree when the
                  // generation bumps — belt-and-braces alongside the
                  // CachedNetworkImage cacheKey, because some platforms hold
                  // the in-memory Image past the cache invalidation.
                  KeyedSubtree(
                    key: ValueKey<String?>(cacheKey),
                    child: avatarUrl != null
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              cacheKey: cacheKey,
                              width: 96.r,
                              height: 96.r,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  AvatarBlock(initials: initials, size: 96),
                              errorWidget: (_, _, _) =>
                                  AvatarBlock(initials: initials, size: 96),
                            ),
                          )
                        : AvatarBlock(initials: initials, size: 96),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 30.r,
                      height: 30.r,
                      decoration: BoxDecoration(
                        color: hasError ? c.urgent : c.action,
                        shape: BoxShape.circle,
                        border: Border.all(color: c.card, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        hasError ? AppIcons.warning : AppIcons.camera,
                        size: AppIconSize.micro.r,
                        // dark glyph reads on both orange + red chips (6.37 / 4.76:1)
                        color: c.onAction,
                      ),
                    ),
                  ),
                  if (isUploading)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(
                          color: Colors.white, // intentional: white-on-dark-overlay
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Gap(AppSpacing.sm.h),
          if (hasError)
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: tt.labelSmall!.copyWith(
                color: c.urgent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            )
          else if (isUploading)
            Text(
              'Uploading…',
              style: tt.labelSmall!.copyWith(
                color: c.text2,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            )
          else
            Text(
              'Tap to change photo',
              style: tt.labelSmall!.copyWith(
                color: c.text3,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
              ),
            ),
        ],
      ),
    );
  }
}

enum ProfileEditAvatarAction { camera, gallery, remove }

class ProfileEditAvatarPickerSheet extends StatelessWidget {
  const ProfileEditAvatarPickerSheet({super.key, required this.hasAvatar});

  final bool hasAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final radius = BorderRadius.vertical(
      top: Radius.circular(AppRadius.card.r),
    );
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(color: c.card, borderRadius: radius),
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 12.h),
              decoration: BoxDecoration(
                color: c.border,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            _SheetAction(
              icon: AppIcons.camera,
              label: 'Take photo',
              onTap: () =>
                  Navigator.of(context).pop(ProfileEditAvatarAction.camera),
            ),
            _SheetAction(
              icon: AppIcons.image,
              label: 'Pick from gallery',
              onTap: () =>
                  Navigator.of(context).pop(ProfileEditAvatarAction.gallery),
            ),
            if (hasAvatar)
              _SheetAction(
                icon: AppIcons.trash,
                label: 'Remove photo',
                destructive: true,
                onTap: () =>
                    Navigator.of(context).pop(ProfileEditAvatarAction.remove),
              ),
            Gap(8.h),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                child: Text(
                  'CANCEL',
                  textAlign: TextAlign.center,
                  style: tt.labelMedium!.copyWith(
                    color: c.text3,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final color = destructive ? c.urgent : c.text1;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.input.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: color),
            Gap(14.w),
            Text(
              label,
              style: tt.bodyLarge!.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
