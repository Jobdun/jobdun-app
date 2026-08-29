import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
///
/// **State vocabulary** — Figma `JobDun-Screens` → Login (node 60:267) draws
/// four states, and all four are wired here. Error is a whole-field
/// treatment, not just a red outline: the fill, the border, the label and the
/// value all move together, so a failed field is obvious without reading the
/// caption.
///
/// | state    | fill            | border            | label + value |
/// |----------|-----------------|-------------------|---------------|
/// | rest     | `surface`       | `borderStrong` 1  | `text1`       |
/// | focus    | `surface`       | `action` 2 + ring | `text1`       |
/// | error    | `urgentBg`      | `urgent` 1.5      | `urgentTx`    |
/// | disabled | `surfaceRaised` | `border`          | `text3`       |
///
/// The states come from a [WidgetStatesController] that [TextField] keeps
/// updated (`focused`, `error`, `disabled`, `hovered`). Reading them from
/// there rather than re-running the validator means the label and the ring
/// stay in step with the border for *every* trigger — typing, blurring, and
/// a form-level `saveAndValidate()` on submit.
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
    this.forcedErrorText,
  });

  final String name;
  // Optional uppercase theme label above the input. When null, the input
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

  /// An error the *server* raised about this field, e.g. "Wrong password" from
  /// Supabase on /login. Renders exactly like a validation failure — red fill,
  /// red label, caption below — because to the user there is no difference.
  ///
  /// Clears itself the moment the field is edited: the message describes a
  /// value that no longer exists, and leaving it up while someone retypes
  /// their password reads as "still wrong" when nothing has been rechecked.
  final String? forcedErrorText;

  @override
  State<JTextField> createState() => _JTextFieldState();
}

class _JTextFieldState extends State<JTextField> {
  late bool _obscured;

  // TextField pushes focused / error / disabled / hovered into this on every
  // change. We listen so the label, fill and focus ring — which live outside
  // the InputDecoration — repaint with the border rather than a frame later.
  final _states = WidgetStatesController();

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _states.addListener(_onStatesChanged);
  }

  @override
  void dispose() {
    _states.removeListener(_onStatesChanged);
    _states.dispose();
    super.dispose();
  }

  void _onStatesChanged() {
    if (!mounted) return;
    // TextField pushes state updates from inside its own didUpdateWidget, so
    // this fires mid-build and a bare setState throws. Defer to after the
    // frame in that case — one extra frame, and only on the transition into
    // or out of an error, which is imperceptible.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  // Set once the user edits after a server error arrives — see
  // [JTextField.forcedErrorText].
  bool _forcedErrorDismissed = false;

  String? get _effectiveForcedError =>
      _forcedErrorDismissed ? null : widget.forcedErrorText;

  bool get _hasError => _states.value.contains(WidgetState.error);
  bool get _isFocused => _states.value.contains(WidgetState.focused);

  @override
  void didUpdateWidget(JTextField old) {
    super.didUpdateWidget(old);
    // A *new* server error re-arms the slot; the same one staying put does not.
    if (widget.forcedErrorText != old.forcedErrorText &&
        widget.forcedErrorText != null) {
      _forcedErrorDismissed = false;
    }
  }

  void _handleChanged(String? value) {
    if (!_forcedErrorDismissed && widget.forcedErrorText != null) {
      setState(() => _forcedErrorDismissed = true);
    }
    widget.onChanged?.call(value);
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
    // Figma `Typography/Label/S` — Inter Regular 14 at full text weight. The
    // old 12px grey label sat below the 4.5:1 floor on a raised surface and
    // read as a hint rather than a name for the field.
    final labelWidget = hasLabel
        ? Text(
            widget.label!,
            style: tt.bodyMedium!.copyWith(
              fontSize: 14,
              height: 1.0,
              color: !widget.enabled
                  ? c.text3
                  : _hasError
                  ? c.urgentTx
                  : c.text1,
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
          child: DecoratedBox(
            // Figma `Elevation/brand focus` — a 3dp ring, no blur. Drawn
            // outside the field so it never eats into the 48dp tap target,
            // and only while focused so it reads as "you are typing here".
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input.r),
              boxShadow: _isFocused && !_hasError
                  ? [
                      BoxShadow(
                        color: c.action.withValues(alpha: 0.2),
                        spreadRadius: 3,
                      ),
                    ]
                  : null,
            ),
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
              onChanged: _handleChanged,
              inputFormatters: widget.inputFormatters,
              maxLength: widget.maxLength,
              maxLines: widget.maxLines,
              autofillHints: widget.autofillHints,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              enableInteractiveSelection: true,
              validator: widget.validator,
              statesController: _states,
              // TextField resolves `style` as a WidgetStateProperty, so the
              // value text can turn red on error without a second rebuild path.
              style: WidgetStateTextStyle.resolveWith(
                (states) => tt.bodyLarge!.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: states.contains(WidgetState.disabled)
                      ? c.text3
                      : states.contains(WidgetState.error)
                      ? c.urgentTx
                      : c.text1,
                ),
              ),
              decoration: InputDecoration(
                // Same trick for the fill: InputDecorator resolves fillColor
                // through WidgetStateProperty.resolveAs, so an errored field
                // washes its whole box rather than just outlining it.
                fillColor: WidgetStateColor.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? c.surfaceRaised
                      : states.contains(WidgetState.error)
                      ? c.urgentBg
                      : c.surface,
                ),
                // Figma pins every field at 48dp.
                constraints: BoxConstraints(minHeight: 48.h),
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
                // A non-null errorText makes TextField report error state,
                // which is what turns the fill, label and value red — the whole
                // treatment falls out of one field rather than a parallel path.
                errorText: _effectiveForcedError,
                // Reserve helper/error space so layout doesn't jump on validation.
                helperText: widget.helperText ?? ' ',
                helperMaxLines: 2,
                errorMaxLines: 2,
                counterText: widget.maxLength == null ? '' : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
