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
import 'manual_upload_sheet.dart';

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

String issuerFor(ManualDocKind kind, String? state) => switch (kind) {
  ManualDocKind.abnCertificate => 'Australian Business Register',
  ManualDocKind.tradeLicence =>
    state == null ? 'State regulator' : '$state Fair Trading',
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
                const _Label(text: 'TRADE CLASS'),
                Gap(6.h),
                _ChoiceDropdown(
                  value: tradeClass,
                  items: manualUploadTradeClasses,
                  onChanged: onTradeClassChanged,
                ),
                Gap(12.h),
              ],
              _Label(text: kind.numberLabel.toUpperCase()),
              Gap(6.h),
              JTextField(
                name: 'document_number',
                label: kind.numberLabel,
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
                _ExpiryRow(expiry: expiry, onTap: onPickExpiry),
              ],
              Gap(8.h),
              Text(
                'Issuer: ${issuerFor(kind, kind.requiresState ? state : null)}',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: c.text3,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Gap(16.h),
        _AttestationCheckbox(
          kind: kind,
          attested: attested,
          enabled: !uploading,
          onChanged: onAttestedChanged,
        ),
        Gap(12.h),
        _PickerBlock(
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
      style: TextStyle(
        fontSize: 11.sp,
        color: context.c.text3,
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
          style: TextStyle(fontSize: 14.sp, color: c.text1),
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
  const _ExpiryRow({required this.expiry, required this.onTap});
  final DateTime? expiry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final label = expiry == null
        ? 'Pick a date'
        : DateFormat('d MMM yyyy').format(expiry!);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(AppIcons.calendar, size: 18.r, color: c.text3),
            Gap(10.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 14.sp,
                color: expiry == null ? c.text3 : c.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerBlock extends StatelessWidget {
  const _PickerBlock({
    required this.pickedFile,
    required this.uploading,
    required this.uploadEnabled,
    required this.onCamera,
    required this.onGallery,
    required this.onUpload,
  });

  final File? pickedFile;
  final bool uploading;

  /// False until the attestation checkbox is ticked — greys out the UPLOAD
  /// button so the user can't bypass the attestation step by mashing tap.
  final bool uploadEnabled;

  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (pickedFile == null) {
      return Row(
        children: [
          Expanded(
            child: JButton(
              label: 'CAMERA',
              variant: JButtonVariant.secondary,
              size: JButtonSize.standard,
              onPressed: onCamera,
            ),
          ),
          Gap(12.w),
          Expanded(
            child: JButton(
              label: 'GALLERY',
              variant: JButtonVariant.primary,
              size: JButtonSize.standard,
              onPressed: onGallery,
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: Image.file(
            pickedFile!,
            height: 180.h,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Gap(12.h),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'CHANGE',
                variant: JButtonVariant.secondary,
                size: JButtonSize.standard,
                onPressed: uploading ? null : onGallery,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: uploading ? 'UPLOADING…' : 'UPLOAD',
                variant: JButtonVariant.primary,
                size: JButtonSize.standard,
                onPressed: (uploading || !uploadEnabled) ? null : onUpload,
              ),
            ),
          ],
        ),
        if (uploading) ...[
          Gap(8.h),
          LinearProgressIndicator(
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation<Color>(c.action),
          ),
        ],
      ],
    );
  }
}

class _AttestationCheckbox extends StatelessWidget {
  const _AttestationCheckbox({
    required this.kind,
    required this.attested,
    required this.enabled,
    required this.onChanged,
  });

  final ManualDocKind kind;
  final bool attested;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  String get _claim => switch (kind) {
    ManualDocKind.abnCertificate =>
      'I attest that I am authorised to act on behalf of the business this ABN '
          'certificate identifies. False attestations may be referred to the '
          'ATO and law enforcement.',
    ManualDocKind.tradeLicence =>
      'I attest that I am the licence holder named on this document and that '
          'the licence is current. False attestations may be referred to the '
          'state regulator and law enforcement.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return InkWell(
      onTap: enabled ? () => onChanged(!attested) : null,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: attested ? c.action : c.border,
            width: attested ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: 2.h),
              child: SizedBox(
                width: 20.r,
                height: 20.r,
                child: Checkbox(
                  value: attested,
                  onChanged: enabled ? (v) => onChanged(v ?? false) : null,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
            Gap(10.w),
            Expanded(
              child: Text(
                _claim,
                style: TextStyle(fontSize: 12.sp, color: c.text2, height: 1.45),
              ),
            ),
          ],
        ),
      ),
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
        Icon(AppIcons.verified, size: 32.r, color: c.verified),
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
