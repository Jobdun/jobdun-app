import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../../app/theme/app_colors.dart';
import '../../theme/app_icons.dart';

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
    this.label,
    this.hint,
    this.prefixIcon,
    this.prefixText,
    this.prefix,
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
    this.maxLines = 1,
    this.autofillHints,
    this.labelTrailing,
    this.focusNode,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.keyboardAppearance,
  });

  final String name;
  // Optional uppercase Oswald label above the input. When null, the input
  // renders without a label — useful for row layouts where one shared
  // FieldLabel sits above several inputs (e.g. SUBURB / STATE / POSTCODE on
  // /profile/edit) and per-field labels would duplicate it.
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final String? prefixText;

  /// Always-visible leading widget, mapped to [InputDecoration.prefixIcon] so
  /// it stays on screen at rest — unlike [prefixText], which Flutter hides
  /// until the field is focused or non-empty. Use for a persistent currency
  /// symbol so it mirrors an always-on [suffixIcon]. Ignored when [prefixIcon]
  /// is also set.
  final Widget? prefix;
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
  // 1 = single-line input (default). Pass higher for multi-line text areas
  // such as the COVER NOTE on /jobs/<id>/apply or ABOUT on /profile/edit.
  final int maxLines;
  final Iterable<String>? autofillHints;

  /// Optional widget rendered on the right side of the label row. Used on
  /// /login to inline "Forgot?" next to the Password label so the escape
  /// hatch lives in industry-standard position.
  final Widget? labelTrailing;

  /// External focus node — required when callers want to drive focus
  /// traversal explicitly (e.g. email → password Next-key wiring on /login).
  /// When null, the underlying FormBuilderTextField creates its own.
  final FocusNode? focusNode;

  /// Autocorrect / IME suggestion bar. Default true (Flutter default).
  /// MUST be disabled for email and password fields — autocorrect mangles
  /// addresses, and the Android suggestion bar steals ~40dp of vertical
  /// space above the keyboard.
  final bool autocorrect;
  final bool enableSuggestions;

  /// iOS-only — tints the system keyboard to match a dark theme. Set to
  /// Brightness.dark on auth screens so the light keyboard doesn't strobe
  /// against the dark scaffold background.
  final Brightness? keyboardAppearance;

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
                _obscured ? AppIcons.eyeClosed : AppIcons.eyeOpen,
                size: AppIconSize.md.r,
                color: c.text3,
              ),
            ),
          )
        : widget.suffixIcon;

    // Label row is rendered outside MergeSemantics so a tappable
    // labelTrailing (e.g. "Forgot?") keeps its own button semantics — merging
    // it with the input's text-field semantics trips the framework's
    // semantics-flush assertion at runtime.
    final hasLabel = widget.label != null;
    final labelWidget = hasLabel
        ? Text(
            widget.label!,
            style: tt.labelMedium!.copyWith(
              color: widget.enabled ? c.text2 : c.text3,
            ),
          )
        : const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasLabel) ...[
          if (widget.labelTrailing != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: labelWidget),
                widget.labelTrailing!,
              ],
            )
          else
            labelWidget,
          Gap(AppSpacing.sm.h),
        ],
        MergeSemantics(
          child: FormBuilderTextField(
            name: widget.name,
            enabled: widget.enabled,
            initialValue: widget.initialValue,
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            keyboardAppearance: widget.keyboardAppearance,
            autocorrect: widget.autocorrect,
            enableSuggestions: widget.enableSuggestions,
            onSubmitted: widget.onSubmitted,
            onChanged: widget.onChanged,
            inputFormatters: widget.inputFormatters,
            maxLength: widget.maxLength,
            maxLines: widget.maxLines,
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
                  ? Icon(widget.prefixIcon, size: AppIconSize.md.r)
                  : widget.prefix,
              // A bare prefix widget (e.g. a "$") should hug the value, not sit
              // centred in the default ~48px icon box. Icon prefixes keep the
              // framework defaults.
              prefixIconConstraints:
                  widget.prefix != null && widget.prefixIcon == null
                  ? const BoxConstraints(minWidth: 0, minHeight: 0)
                  : null,
              suffixIcon: effectiveSuffix,
              // Reserve helper/error space so layout doesn't jump on validation.
              helperText: widget.helperText ?? ' ',
              helperMaxLines: 2,
              errorMaxLines: 2,
              counterText: widget.maxLength == null ? '' : null,
            ),
          ),
        ),
      ],
    );
  }
}
