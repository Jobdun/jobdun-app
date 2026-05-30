import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../domain/entities/verification_document.dart';
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';
import 'manual_upload_form.dart';
import 'manual_upload_priming.dart';

/// Tight, role-scoped surface for the manual-upload sheet. Only the two real
/// fallback shapes are exposed — anything else (white card, PI, etc.) belongs
/// in a different upload UI when it ships.
enum ManualDocKind { abnCertificate, tradeLicence }

extension ManualDocKindX on ManualDocKind {
  DocType get docType => switch (this) {
    ManualDocKind.abnCertificate => DocType.abnCertificate,
    ManualDocKind.tradeLicence => DocType.tradeLicence,
  };

  String get sheetTitle => switch (this) {
    ManualDocKind.abnCertificate => 'Upload your ABN certificate',
    ManualDocKind.tradeLicence => 'Upload your trade licence',
  };

  String get numberLabel => switch (this) {
    ManualDocKind.abnCertificate => 'ABN',
    ManualDocKind.tradeLicence => 'Licence number',
  };

  String get numberHint => switch (this) {
    ManualDocKind.abnCertificate => '11 digits',
    ManualDocKind.tradeLicence => 'e.g. EL-12345',
  };

  bool get requiresState => this == ManualDocKind.tradeLicence;
  bool get requiresExpiry => this == ManualDocKind.tradeLicence;
}

/// Opens the manual-upload bottom sheet. Returns `true` when the user
/// successfully submitted a document, `false` (or `null` from a swipe-dismiss)
/// otherwise — callers use this to decide whether to invalidate receipts and
/// close any upstream chrome.
Future<bool> showManualUploadSheet({
  required BuildContext context,
  required ManualDocKind kind,
  String? prefilledState,
  String? prefilledNumber,
}) async {
  final result = await showJSheet<bool>(
    context: context,
    expand: false,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _ManualUploadSheet(
      kind: kind,
      prefilledState: prefilledState,
      prefilledNumber: prefilledNumber,
    ),
  );
  return result ?? false;
}

class _ManualUploadSheet extends ConsumerStatefulWidget {
  const _ManualUploadSheet({
    required this.kind,
    this.prefilledState,
    this.prefilledNumber,
  });

  final ManualDocKind kind;
  final String? prefilledState;
  final String? prefilledNumber;

  @override
  ConsumerState<_ManualUploadSheet> createState() => _ManualUploadSheetState();
}

class _ManualUploadSheetState extends ConsumerState<_ManualUploadSheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  File? _pickedFile;
  bool _uploading = false;
  bool _done = false;
  bool _attested = false;
  String? _error;
  bool _phoneRequired = false;
  String _state = 'NSW';
  String _tradeClass = manualUploadTradeClasses.first;
  DateTime? _expiry;

  @override
  void initState() {
    super.initState();
    if (widget.prefilledState != null &&
        manualUploadStates.contains(widget.prefilledState)) {
      _state = widget.prefilledState!;
    }
  }

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
    if (!_attested) return; // Defensive — UI already blocks this path.
    // F2: mirror the auto-path phone gate. Both edge functions refuse to mint
    // a verified row without a verified phone (the identity anchor); the manual
    // path must hold the same bar. Read the verified state off the profile
    // controller (never Supabase from a widget) — it's already hydrated by the
    // profile page that hosts every entry point into this sheet.
    final phoneVerified = ref.read(
      profileControllerProvider.select((s) => s.profile?.isPhoneVerified),
    );
    if (phoneVerified != true) {
      _showPhoneRequired();
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final number = (form.value['document_number'] as String? ?? '').trim();
    final issuer = issuerFor(
      widget.kind,
      widget.kind.requiresState ? _state : null,
    );

    setState(() {
      _uploading = true;
      _error = null;
      _phoneRequired = false;
    });
    try {
      await ref
          .read(verificationDatasourceProvider)
          .uploadDocument(
            tradeId: userId,
            docType: widget.kind.docType,
            file: file,
            state: widget.kind.requiresState ? _state : null,
            issuer: issuer,
            documentNumber: number.isEmpty ? null : number,
            expiryDate: _expiry,
            // A3: only a trade licence carries a trade class — ABN certificates
            // have none, so leave it null and don't write the column.
            tradeClass: widget.kind == ManualDocKind.tradeLicence
                ? _tradeClass
                : null,
          );
      if (!mounted) return;
      // Fire-and-forget attestation audit — admin sees this alongside the
      // doc in the review queue.
      await ref
          .read(verificationFunnelLoggerProvider.notifier)
          .log(
            'manual_upload_attestation_recorded',
            metadata: {
              'kind': widget.kind.name,
              'doc_type': widget.kind.docType.dbValue,
              if (widget.kind.requiresState) 'state': _state,
              if (widget.kind == ManualDocKind.tradeLicence)
                'trade_class': _tradeClass,
              if (number.isNotEmpty) 'document_number': number,
            },
          );
      if (!mounted) return;
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

  // F2: block the upload and steer the user to verify their phone — same intent
  // as the edge-function `phone_required` gate. Inline (not a snackbar) so the
  // CTA stays reachable while the sheet is open.
  void _showPhoneRequired() {
    setState(() {
      _uploading = false;
      _phoneRequired = true;
      _error =
          'Verify your phone number first — it confirms the licence is '
          'really yours. Tap below to verify in under a minute.';
    });
  }

  void _goVerifyPhone() {
    Navigator.of(context).pop(false);
    context.push('/profile/verify-phone');
  }

  Future<void> _onPickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 2, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    // SingleChildScrollView is load-bearing: the sheet contains a form, an
    // attestation block, picker buttons, optional 180px preview, and the
    // keyboard's viewInsets pad. On a 360w / sub-800h screen the column
    // exceeds the modal's maxHeight and RenderFlex overflows. Wrapping in
    // a scroll view keeps the sheet content reachable in every keyboard
    // and content state without resorting to expand=true (which would make
    // the sheet fullscreen and feel jarring for a quick upload).
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h + viewInsets),
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
              _done ? 'Sent for review' : widget.kind.sheetTitle,
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
                  : 'A real person reviews uploads — usually within 24 hours.',
              style: TextStyle(fontSize: 13.sp, color: c.text2, height: 1.45),
            ),
            Gap(16.h),
            if (_done)
              ManualUploadDoneBlock(
                onClose: () => Navigator.of(context).pop(true),
              )
            else ...[
              const ManualUploadPrimingBlock(),
              Gap(16.h),
              ManualUploadActiveBody(
                kind: widget.kind,
                formKey: _formKey,
                state: _state,
                onStateChanged: (v) => setState(() => _state = v),
                tradeClass: _tradeClass,
                onTradeClassChanged: (v) => setState(() => _tradeClass = v),
                expiry: _expiry,
                onPickExpiry: _onPickExpiry,
                prefilledNumber: widget.prefilledNumber,
                pickedFile: _pickedFile,
                uploading: _uploading,
                attested: _attested,
                onAttestedChanged: (v) => setState(() => _attested = v),
                onCamera: () => _pick(ImageSource.camera),
                onGallery: () => _pick(ImageSource.gallery),
                onUpload: _upload,
              ),
            ],
            if (_error != null) ...[
              Gap(12.h),
              Text(
                _error!,
                style: TextStyle(fontSize: 12.sp, color: c.urgent),
              ),
              if (_phoneRequired) ...[
                Gap(12.h),
                _PhoneRequiredCta(onVerifyPhone: _goVerifyPhone),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// F2: phone-verify CTA shown inline when a manual upload is blocked because
/// the user's phone isn't verified. Single caller — the sheet above.
class _PhoneRequiredCta extends StatelessWidget {
  const _PhoneRequiredCta({required this.onVerifyPhone});

  final VoidCallback onVerifyPhone;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: JButton(
        label: 'VERIFY MY PHONE',
        variant: JButtonVariant.primary,
        size: JButtonSize.standard,
        onPressed: onVerifyPhone,
      ),
    );
  }
}
