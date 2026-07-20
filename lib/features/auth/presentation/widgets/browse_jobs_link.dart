import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// Guest-browsing entry (App Review 5.1.1(v)) — the auth wall must always
/// offer a no-account path to the public job browser. Same inline-link idiom
/// as the login page's create-account link.
class BrowseJobsLink extends StatelessWidget {
  const BrowseJobsLink({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Browse open jobs without an account.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: tt.bodyMedium!.copyWith(color: c.text2),
              children: [
                const TextSpan(text: 'Just looking? '),
                TextSpan(
                  text: 'Browse open jobs',
                  style: tt.bodyMedium!.copyWith(
                    color: c.actionInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
