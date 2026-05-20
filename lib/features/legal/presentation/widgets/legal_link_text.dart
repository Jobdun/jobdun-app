import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';

/// Full inline legal link — "By continuing, you agree to our Terms & Privacy Policy."
///
/// Set [minimal] to true for a smaller footer variant (login page).
class LegalLinkText extends StatefulWidget {
  const LegalLinkText({super.key, this.minimal = false});

  final bool minimal;

  @override
  State<LegalLinkText> createState() => _LegalLinkTextState();
}

class _LegalLinkTextState extends State<LegalLinkText> {
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/terms');
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => context.push('/legal/privacy');
  }

  @override
  void dispose() {
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final baseStyle = widget.minimal
        ? tt.bodySmall!.copyWith(color: c.text3, fontSize: 11.sp)
        : tt.bodySmall!.copyWith(color: c.text2, height: 1.4);

    final linkStyle = baseStyle.copyWith(
      color: c.action,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.action,
    );

    return Semantics(
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: baseStyle,
          children: [
            const TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: linkStyle,
              recognizer: _termsTap,
              semanticsLabel: 'Open Terms of Service',
            ),
            const TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: linkStyle,
              recognizer: _privacyTap,
              semanticsLabel: 'Open Privacy Policy',
            ),
            const TextSpan(text: '.'),
          ],
        ),
      ),
    );
  }
}
