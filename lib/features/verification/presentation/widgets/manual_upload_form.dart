import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import 'manual_doc_kind.dart';
import 'manual_upload_controls.dart';

const manualUploadStates = [
  'NSW',
  'VIC',
  'QLD',
  'SA',
  'WA',
  'TAS',
  'ACT',
  'NT',
];

/// Trade classes a manual licence can be filed under. Single source of truth —
/// the auto-path `wizard_licence_step.dart` imports this list too, so the two
/// surfaces never drift. Expand per regulator once real adapters land.
const manualUploadTradeClasses = [
  'Electrician',
  'Plumber',
  'Carpenter',
  'Painter',
  'Tiler',
  'Plasterer',
  'Refrigeration mechanic',
  'Gasfitter',
];

/// U1.1: true when [kind] demands an expiry date the user hasn't picked yet.
/// A credential stored without `expiry_date` can never flip
/// `TradePublicCredential.isExpired`, so the badge would read "verified"
/// forever — the sheet refuses the upload until a date exists.
bool expiryMissing(ManualDocKind kind, DateTime? expiry) =>
    kind.requiresExpiry && expiry == null;

/// U1.2: map any pick/upload failure to a human-readable line. The raw error
/// string goes to the verification funnel log; the user never sees it.
String humanUploadError(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('socketexception') ||
      s.contains('timeout') ||
      s.contains('failed host lookup') ||
      s.contains('connection')) {
    return "Couldn't upload — check your connection and try again.";
  }
  if (s.contains('413') ||
      s.contains('payload too large') ||
      s.contains('maximum allowed size') ||
      s.contains('too large')) {
    return 'That file is too big — keep it under 10 MB.';
  }
  if (s.contains('403') || s.contains('unauthorized') || s.contains('jwt')) {
    return 'Upload was refused. Log out and back in, then retry.';
  }
  return 'Something went wrong. Try again in a minute.';
}

/// Derived issuer string for the kinds whose issuer is fixed or state-derived.
/// Public liability is insurer-issued (free text), so the sheet passes the
/// user-typed insurer through instead of calling this.
String issuerFor(ManualDocKind kind, String? state) => switch (kind) {
  ManualDocKind.abnCertificate => 'Australian Business Register',
  ManualDocKind.tradeLicence =>
    state == null ? 'State regulator' : '$state Fair Trading',
  ManualDocKind.whiteCard =>
    state == null
        ? 'Registered training organisation'
        : '$state RTO / SafeWork',
  ManualDocKind.publicLiability => 'Insurer',
};

/// Active body of the manual-upload sheet (form fields + file picker).
/// Extracted from `manual_upload_sheet.dart` to respect the 500-LOC ceiling.
class ManualUploadActiveBody extends StatelessWidget {
  const ManualUploadActiveBody({
    super.key,
    required this.kind,
    required this.formKey,
    required this.state,
    required this.onStateChanged,
    required this.tradeClass,
    required this.onTradeClassChanged,
    required this.expiry,
    this.expiryError,
    this.expiryRowKey,
    required this.onPickExpiry,
    required this.prefilledNumber,
    required this.pickedFile,
    required this.uploading,
    required this.attested,
    required this.onAttestedChanged,
    required this.onCamera,
    required this.onGallery,
    required this.onUpload,
  });

  final ManualDocKind kind;
  final GlobalKey<FormBuilderState> formKey;
  final String state;
  final ValueChanged<String> onStateChanged;

  /// Selected trade class for a licence upload (A3) — `null`/ignored for ABN
  /// certificates. Captured so the approved row carries `licence_trade_class`
  /// instead of leaving the counterparty `licence_class` blank.
  final String tradeClass;
  final ValueChanged<String> onTradeClassChanged;

  final DateTime? expiry;

  /// U1.1: validation error for the expiry row (the date lives outside the
  /// FormBuilder, so the sheet validates it explicitly on UPLOAD).
  final String? expiryError;

  /// Anchors `Scrollable.ensureVisible` so a failed expiry validation scrolls
  /// the row back into view above the keyboard.
  final Key? expiryRowKey;

  final VoidCallback onPickExpiry;
  final String? prefilledNumber;
  final File? pickedFile;
  final bool uploading;

  /// Attestation checkbox state. The UPLOAD button only fires when this is
  /// true — anchors the legal "I claim this is mine" hook for the admin
  /// reviewer (and the funnel event written by the parent sheet).
  final bool attested;
  final ValueChanged<bool> onAttestedChanged;

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onUpload;

  bool _isFormReady() => pickedFile != null && (formKey.currentState != null);

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormBuilder(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          initialValue: {'document_number': prefilledNumber ?? ''},
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kind.requiresState) ...[
                const _Label(text: 'STATE'),
                Gap(6.h),
                _ChoiceDropdown(
                  value: state,
                  items: manualUploadStates,
                  onChanged: onStateChanged,
                ),
                Gap(12.h),
              ],
              // Trade class is licence-only (A3). A White Card has a state but
              // is not filed under a class, so this is gated separately from
              // [requiresState].
              if (kind.requiresTradeClass) ...[
                const _Label(text: 'TRADE CLASS'),
                Gap(6.h),
                _ChoiceDropdown(
                  value: tradeClass,
                  items: manualUploadTradeClasses,
                  onChanged: onTradeClassChanged,
                ),
                Gap(12.h),
              ],
              // Public liability is insurer-issued, so capture a free-text
              // insurer name (the others derive their issuer from the state).
              if (kind.requiresIssuer) ...[
                const _Label(text: 'INSURER'),
                Gap(6.h),
                // U1.4: the eyebrow _Label above is the single label — passing
                // label: here too rendered the field name twice.
                JTextField(
                  name: 'insurer',
                  hint: 'e.g. CGU, QBE, Allianz',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Required' : null,
                ),
                Gap(12.h),
              ],
              _Label(text: kind.numberLabel.toUpperCase()),
              Gap(6.h),
              // U1.4: eyebrow above is the single label (see INSURER note).
              JTextField(
                name: 'document_number',
                hint: kind.numberHint,
                keyboardType: kind == ManualDocKind.abnCertificate
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: kind == ManualDocKind.abnCertificate
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                maxLength: kind == ManualDocKind.abnCertificate ? 11 : null,
                validator: _numberValidator,
              ),
              if (kind.requiresExpiry) ...[
                Gap(8.h),
                const _Label(text: 'EXPIRES'),
                Gap(6.h),
                _ExpiryRow(
                  key: expiryRowKey,
                  expiry: expiry,
                  errorText: expiryError,
                  onTap: onPickExpiry,
                ),
              ],
              Gap(8.h),
              Text(
                'Issuer: ${issuerFor(kind, kind.requiresState ? state : null)}',
                style: tt.bodySmall!.copyWith(
                  color: c.text3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Gap(16.h),
        ManualUploadAttestationCheckbox(
          kind: kind,
          attested: attested,
          enabled: !uploading,
          onChanged: onAttestedChanged,
        ),
        Gap(12.h),
        ManualUploadPickerBlock(
          pickedFile: pickedFile,
          uploading: uploading,
          uploadEnabled: attested,
          onCamera: onCamera,
          onGallery: onGallery,
          onUpload: () {
            formKey.currentState?.saveAndValidate();
            if (_isFormReady() && attested) onUpload();
          },
        ),
      ],
    );
  }

  String? _numberValidator(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Required';
    if (kind == ManualDocKind.abnCertificate) return Validators.abn(value);
    return null;
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        letterSpacing: 0.6,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _ChoiceDropdown extends StatelessWidget {
  const _ChoiceDropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: c.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          dropdownColor: c.surface,
          style: tt.titleSmall!.copyWith(color: c.text1),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => v == null ? null : onChanged(v),
        ),
      ),
    );
  }
}

class _ExpiryRow extends StatelessWidget {
  const _ExpiryRow({
    super.key,
    required this.expiry,
    required this.onTap,
    this.errorText,
  });
  final DateTime? expiry;
  final VoidCallback onTap;

  /// U1.1: set when UPLOAD was pressed without a date — turns the border
  /// urgent and renders the message beneath, mirroring JTextField's slot.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final label = expiry == null
        ? 'Pick a date'
        : DateFormat('d MMM yyyy').format(expiry!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8.r),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(8.r),
              border: Border.all(
                color: errorText == null ? c.border : c.urgent,
                width: errorText == null ? 1 : 1.5,
              ),
            ),
            child: Row(
              children: [
                Icon(AppIcons.calendar, size: AppIconSize.md.r, color: c.text3),
                Gap(10.w),
                Text(
                  label,
                  style: tt.titleSmall!.copyWith(
                    color: expiry == null ? c.text3 : c.text1,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          Gap(4.h),
          Text(errorText!, style: tt.bodySmall!.copyWith(color: c.urgent)),
        ],
      ],
    );
  }
}

class ManualUploadDoneBlock extends StatelessWidget {
  const ManualUploadDoneBlock({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // U1.7: land the peak-end moment — 180ms ease scale/fade, no bounce
        // (MASTER motion rules). Static icon read as "nothing happened".
        // Ticker-driven (not flutter_animate) so widget tests never trip on
        // a pending Timer at teardown.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Icon(
            AppIcons.verified,
            size: AppIconSize.feature.r,
            color: c.verified,
          ),
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
          ),
        ),
        Gap(12.h),
        SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'DONE',
            variant: JButtonVariant.primary,
            size: JButtonSize.standard,
            onPressed: onClose,
          ),
        ),
      ],
    );
  }
}
