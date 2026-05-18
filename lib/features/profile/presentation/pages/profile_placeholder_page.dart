import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/tappable_icon.dart';

/// Stub destination for Profile sub-pages not built yet (T2 links into
/// placeholders by design). Honest "coming soon" — no fake content.
class ProfilePlaceholderPage extends StatelessWidget {
  const ProfilePlaceholderPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: TappableIcon(
          icon: Iconsax.arrow_left,
          semanticLabel: 'Back',
          onTap: () => context.pop(),
          color: c.text1,
        ),
        title: Text(title, style: tt.titleLarge!.copyWith(color: c.text1)),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Iconsax.size, size: AppIconSize.xxl.r, color: c.text3),
              Gap(16.h),
              Text(
                '$title is coming soon',
                textAlign: TextAlign.center,
                style: tt.bodyMedium!.copyWith(
                  color: c.text1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Gap(8.h),
              Text(
                'This section is being built. Check back in an upcoming '
                'update.',
                textAlign: TextAlign.center,
                style: tt.bodySmall!.copyWith(color: c.text3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
