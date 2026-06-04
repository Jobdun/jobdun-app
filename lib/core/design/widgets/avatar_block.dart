import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../app/theme/app_colors.dart';

class AvatarBlock extends StatelessWidget {
  const AvatarBlock({
    super.key,
    required this.initials,
    this.size = 44,
    this.bg,
    this.imageUrl,
    this.circle = false,
  });

  final String initials;
  final double size;
  final Color? bg;
  // When set + non-empty, shows the photo (with the initials block as the
  // placeholder/error fallback). [circle] swaps the rounded-square for a circle.
  final String? imageUrl;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final fs = size >= 64
        ? 22.0
        : size >= 50
        ? 16.0
        : 14.0;
    final radius = circle
        ? BorderRadius.circular(size.r)
        : BorderRadius.circular(AppRadius.avatar.r);

    final fallback = Container(
      width: size.r,
      height: size.r,
      decoration: BoxDecoration(
        color: bg ?? c.surfaceRaised,
        borderRadius: radius,
      ),
      child: Center(
        child: Text(
          initials,
          style: tt.labelLarge!.copyWith(
            fontSize: fs,
            letterSpacing: 0.04 * fs,
            color: c.text1,
          ),
        ),
      ),
    );

    final url = imageUrl;
    if (url == null || url.isEmpty) return fallback;
    return ClipRRect(
      borderRadius: radius,
      child: CachedNetworkImage(
        imageUrl: url,
        width: size.r,
        height: size.r,
        fit: BoxFit.cover,
        placeholder: (_, _) => fallback,
        errorWidget: (_, _, _) => fallback,
      ),
    );
  }
}
