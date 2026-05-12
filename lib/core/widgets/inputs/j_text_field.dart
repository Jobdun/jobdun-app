import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../app/theme/app_colors.dart';

/// Production text field for all forms. Wraps [FormBuilderTextField] so it
/// participates in [FormBuilder] state, validation, and submission.
///
/// Renders a sentence-case label above the field, the field itself (styled
/// from the theme's [InputDecorationTheme]), and a reserved helper/error
/// slot below so layout does not jump when validation fires.
class JTextField extends StatefulWidget {
  const JTextField({
    super.key,
    required this.name,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.suffixIcon,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.helperText,
    this.initialValue,
    this.controller,
    this.inputFormatters,
    this.maxLength,
    this.autofillHints,
  });

  final String name;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final ValueChanged<String?>? onSubmitted;
  final ValueChanged<String?>? onChanged;
  final bool enabled;
  final String? helperText;
  final String? initialValue;
  final TextEditingController? controller;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final Iterable<String>? autofillHints;

  @override
  State<JTextField> createState() => _JTextFieldState();
}

class _JTextFieldState extends State<JTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  void _togglePassword() => setState(() => _obscured = !_obscured);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final Widget? effectiveSuffix = widget.obscureText
        ? Semantics(
            button: true,
            label: _obscured ? 'Show password' : 'Hide password',
            child: IconButton(
              onPressed: _togglePassword,
              icon: Icon(
                _obscured ? Iconsax.eye_slash : Iconsax.eye,
                size: 18.r,
                color: c.text3,
              ),
            ),
          )
        : widget.suffixIcon;

    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: tt.labelMedium!.copyWith(
              color: widget.enabled ? c.text2 : c.text3,
            ),
          ),
          Gap(AppSpacing.sm.h),
          FormBuilderTextField(
            name: widget.name,
            enabled: widget.enabled,
            initialValue: widget.initialValue,
            controller: widget.controller,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            autofillHints: widget.autofillHints,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            enableInteractiveSelection: true,
            validator: widget.validator,
            style: tt.bodyLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              prefixText: widget.prefixText,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(widget.prefixIcon, size: 18.r)
                  : null,
              suffixIcon: effectiveSuffix,
              // Reserve helper/error space so layout doesn't jump on validation.
              helperText: widget.helperText ?? ' ',
              helperMaxLines: 2,
              errorMaxLines: 2,
              counterText: widget.maxLength == null ? '' : null,
            ),
          ),
        ],
      ),
    );
  }
}
