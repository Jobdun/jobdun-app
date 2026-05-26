import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/theme/app_icons.dart';
import '../../domain/entities/verification_document.dart';
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';

/// Manual document upload fallback. Shown from any wizard failure surface
/// when the regulator can't confirm the user automatically.
///
/// Writes to verification_documents (status='pending') via the existing
/// VerificationRemoteDataSource — admin review flips the row to verified
/// later. Receipts panel on the profile picks up the new row through
/// `verificationsForUserProvider` invalidation on close.
Future<void> showManualUploadSheet({
  required BuildContext context,
  required DocType docType,
}) {
  return showJSheet<void>(
    context: context,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ManualUploadSheet(docType: docType),
  );
}

class _ManualUploadSheet extends ConsumerStatefulWidget {
  const _ManualUploadSheet({required this.docType});

  final DocType docType;

  @override
  ConsumerState<_ManualUploadSheet> createState() => _ManualUploadSheetState();
}

class _ManualUploadSheetState extends ConsumerState<_ManualUploadSheet> {
  File? _pickedFile;
  bool _uploading = false;
  bool _done = false;
  String? _error;

  String get _title => switch (widget.docType) {
    DocType.abnCertificate => 'Upload your ABN certificate',
    DocType.tradeLicence => 'Upload your trade licence',
    _ => 'Upload document',
  };

  Future<void> _pick(ImageSource source) async {
    setState(() => _error = null);
    try {
      final file = await ImageUploadService.pickCropCompress(
        source: source,
        aspect: ImageAspect.free,
      );
      if (!mounted || file == null) return;
      setState(() => _pickedFile = file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _upload() async {
    final userId = ref.read(currentUserIdSyncProvider);
    final file = _pickedFile;
    if (userId == null || file == null) return;
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      await ref
          .read(verificationDatasourceProvider)
          .uploadDocument(tradeId: userId, docType: widget.docType, file: file);
      if (!mounted) return;
      // Refresh receipts so the profile rows reflect the new pending row.
      ref.invalidate(verificationsForUserProvider(userId));
      setState(() {
        _uploading = false;
        _done = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(16.h),
            Text(
              _done ? 'Sent for review' : _title,
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(8.h),
            Text(
              _done
                  ? 'A reviewer will check this within 24 hours. We\'ll '
                        'update your profile receipts when it\'s approved.'
                  : 'Pick a clear photo or PDF. A reviewer will confirm '
                        'it within 24 hours.',
              style: TextStyle(fontSize: 13.sp, color: c.text2, height: 1.45),
            ),
            Gap(20.h),
            if (_done)
              _DoneBlock(onClose: () => Navigator.of(context).maybePop())
            else
              _PickerBlock(
                pickedFile: _pickedFile,
                uploading: _uploading,
                onCamera: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
                onUpload: _upload,
              ),
            if (_error != null) ...[
              Gap(12.h),
              Text(
                _error!,
                style: TextStyle(fontSize: 12.sp, color: c.urgent),
              ),
            ],
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
    required this.onCamera,
    required this.onGallery,
    required this.onUpload,
  });

  final File? pickedFile;
  final bool uploading;
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
                onPressed: uploading ? null : onUpload,
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

class _DoneBlock extends StatelessWidget {
  const _DoneBlock({required this.onClose});

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
