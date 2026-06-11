import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:photo_view/photo_view.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import 'manual_doc_kind.dart';

/// Camera/gallery picker + UPLOAD button for the manual-upload sheet. Extracted
/// from `manual_upload_form.dart` to keep that file under the 500-LOC ceiling.
class ManualUploadPickerBlock extends StatelessWidget {
  const ManualUploadPickerBlock({
    super.key,
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
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // U1.5: the priming card's first rule is "no glare, edges in frame" —
        // tap-to-enlarge lets the user actually self-check legibility before
        // committing to a 24 h review round-trip.
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _PickedPreviewViewer(file: pickedFile!),
            ),
          ),
          child: Hero(
            tag: 'verification:picked',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.r),
              child: Image.file(
                pickedFile!,
                height: 180.h,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        Gap(4.h),
        Text(
          "Tap to check it's readable",
          style: tt.bodySmall!.copyWith(color: c.text3),
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
        // U1.3: a silently-greyed UPLOAD reads as broken — state the cause.
        if (!uploadEnabled && !uploading) ...[
          Gap(8.h),
          Text(
            'Tick the declaration above to enable upload',
            style: tt.bodySmall!.copyWith(color: c.text3),
          ),
        ],
      ],
    );
  }
}

/// Full-screen zoomable view of the just-picked document photo (U1.5). Single
/// caller — the picker block above.
class _PickedPreviewViewer extends StatelessWidget {
  const _PickedPreviewViewer({required this.file});

  final File file;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(AppIcons.close, size: AppIconSize.md.r, color: c.text1),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PhotoView(
        imageProvider: FileImage(file),
        backgroundDecoration: BoxDecoration(color: c.background),
        heroAttributes: const PhotoViewHeroAttributes(
          tag: 'verification:picked',
        ),
      ),
    );
  }
}

/// The "I attest this is mine" checkbox. The UPLOAD button only fires when this
/// is ticked — anchors the legal claim for the admin reviewer (and the funnel
/// event written by the parent sheet). Copy is per-kind.
class ManualUploadAttestationCheckbox extends StatelessWidget {
  const ManualUploadAttestationCheckbox({
    super.key,
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
    ManualDocKind.whiteCard =>
      'I attest that I hold this construction induction (White) card and that '
          'the details are accurate. False attestations may be referred to the '
          'regulator and law enforcement.',
    ManualDocKind.publicLiability =>
      'I attest that I hold this public liability insurance policy and that it '
          'is current. False attestations may be referred to the insurer and '
          'law enforcement.',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // U1.8: MergeSemantics — TalkBack/VoiceOver reads the checkbox and its
    // legal claim as one node instead of an unlabelled checkbox + loose text.
    return MergeSemantics(
      child: InkWell(
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
                  style: tt.bodySmall!.copyWith(height: 1.45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
