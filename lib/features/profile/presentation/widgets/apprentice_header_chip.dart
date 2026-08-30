import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// "2ND-YEAR CARPENTER APPRENTICE" — the identity line on an apprentice
/// profile, in place of the plain trade chip.
///
/// Sits on c.surfaceRaised, which carries c.text1 ONLY (text2 is 4.04:1 and
/// text3 is 3.54:1 on that ground, both under the 4.5 body floor).
///
/// Deliberately not orange: c.action is reserved for CTAs and critical status,
/// and "what someone is" is neither.
class ApprenticeHeaderChip extends StatelessWidget {
  const ApprenticeHeaderChip({super.key, required this.headline});

  final String headline;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
      ),
      child: Text(headline, style: tt.labelMedium!.copyWith(color: c.text1)),
    );
  }
}
