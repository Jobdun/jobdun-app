import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';

/// Required acceptance checkbox for the signup flow.
/// Pre-checked = false by default (AU law: pre-checked consent is invalid).
class LegalAcceptanceCheckbox extends StatefulWidget {
  const LegalAcceptanceCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? errorText;

  @override
  State<LegalAcceptanceCheckbox> createState() =>
      _LegalAcceptanceCheckboxState();
}

class _LegalAcceptanceCheckboxState extends State<LegalAcceptanceCheckbox> {
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

    final linkStyle = tt.bodySmall!.copyWith(
      color: c.action,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: c.action,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          button: true,
          checked: widget.value,
          label: 'Accept Terms of Service and Privacy Policy',
          child: InkWell(
            onTap: () => widget.onChanged(!widget.value),
            borderRadius: BorderRadius.circular(AppRadius.chip.r),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 4.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 24.r,
                      height: 24.r,
                      child: Checkbox(
                        value: widget.value,
                        onChanged: (v) => widget.onChanged(v ?? false),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        activeColor: c.action,
                      ),
                    ),
                  ),
                  Gap(8.w),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: tt.bodySmall!.copyWith(
                          color: c.text2,
                          height: 1.5,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
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
                          const TextSpan(text: '. Required.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          Padding(
            padding: EdgeInsets.only(left: 32.w, top: 2.h),
            child: Text(
              widget.errorText!,
              style: tt.bodySmall!.copyWith(color: c.urgent, fontSize: 12.sp),
            ),
          ),
        ],
      ],
    );
  }
}
