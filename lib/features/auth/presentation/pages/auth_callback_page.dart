import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';

/// Web-only landing page for `/auth/callback` — where Supabase's OAuth
/// redirect flow and email-verification links send the browser back after
/// leaving the app. `supabase_flutter` parses the session out of the URL on
/// its own; this page just holds a loading state while that happens and
/// while `AuthController.onAuthStateChange` picks up the session. The
/// router's `redirect:` logic (already reactive to auth state) sends the
/// user on to `/home` — or back to `/login` if the exchange never lands —
/// with no navigation logic needed here.
class AuthCallbackPage extends StatelessWidget {
  const AuthCallbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: c.action),
            Gap(AppSpacing.md.h),
            Text(
              'Signing you in…',
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
          ],
        ),
      ),
    );
  }
}
