import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/providers/current_user_provider.dart';
import '../../../../../core/design/widgets/field_label.dart';
import '../../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../../core/services/image_upload_service.dart';
import '../../../../../core/utils/string_utils.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../auth/presentation/providers/auth_provider.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../providers/profile_provider.dart';
import '../profile_edit_avatar.dart';
import 'edit_sheet_scaffold.dart';

/// Quick-edit sheet for identity: avatar, display name, and (tradies) legal
/// name. Avatar changes persist instantly through the existing upload flow and
/// never set the dirty flag; the name fields save via patches.
class IdentitySheet extends ConsumerStatefulWidget {
  const IdentitySheet({super.key});

  @override
  ConsumerState<IdentitySheet> createState() => _IdentitySheetState();
}

class _IdentitySheetState extends ConsumerState<IdentitySheet> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _dirty = false;
  bool _saving = false;
  String? _error;
  String? _avatarError;
  int _avatarCacheGen = 0;

  /// Fresh sign-ups land here with an empty profile row; fall back to the
  /// name they typed at sign-up (auth.users.user_metadata.full_name).
  String? get _metadataFullName => ref.read(signupFullNameProvider);

  Future<void> _pickAvatar() async {
    final hasAvatar =
        ref.read(profileControllerProvider).profile?.avatarUrl != null;
    final action = await showJSheet<ProfileEditAvatarAction>(
      context: context,
      backgroundColor: context.c.card,
      builder: (_) => ProfileEditAvatarPickerSheet(hasAvatar: hasAvatar),
    );
    if (action == null || !mounted) return;

    setState(() => _avatarError = null);
    final controller = ref.read(profileControllerProvider.notifier);

    if (action == ProfileEditAvatarAction.remove) {
      final ok = await controller.removeAvatar();
      if (!mounted) return;
      setState(() {
        if (ok) {
          _avatarCacheGen++;
        } else {
          _avatarError = "Couldn't remove photo — tap to retry.";
        }
      });
      return;
    }

    final source = action == ProfileEditAvatarAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    File? file;
    try {
      file = await ImageUploadService.pickCropCompress(
        source: source,
        aspect: ImageAspect.square,
      );
    } on UploadGuardException catch (error) {
      if (!mounted) return;
      setState(() => _avatarError = error.message);
      return;
    }
    if (file == null || !mounted) return;

    final ok = await controller.uploadAvatar(file);
    if (!mounted) return;
    setState(() {
      if (ok) {
        _avatarCacheGen++;
      } else {
        _avatarError = 'Upload failed — tap to retry.';
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.saveAndValidate() ?? false)) return;
    final values = _formKey.currentState!.value;
    final isTrade =
        ref.read(authControllerProvider.select((s) => s.role)) ==
        UserRole.trade;
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          user: UserProfilePatch(
            displayName: Some((values['display_name'] as String).trim()),
          ),
          trade: isTrade
              ? TradeProfilePatch(
                  fullName: Some((values['full_name'] as String).trim()),
                )
              : null,
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            ref.read(profileControllerProvider).error ??
            "Couldn't save. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider);
    final profile = state.profile;
    final tp = state.tradeProfile;
    final isTrade =
        ref.watch(authControllerProvider.select((s) => s.role)) ==
        UserRole.trade;

    return EditSheetScaffold(
      title: 'Identity & photo',
      isDirty: _dirty,
      isSaving: _saving,
      error: _error,
      onSave: _save,
      body: FormBuilder(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        onChanged: () {
          if (!_dirty) setState(() => _dirty = true);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileEditAvatarHeader(
              avatarUrl: profile?.avatarUrl,
              initials: StringUtils.initials(profile?.displayName ?? '?'),
              isUploading: state.isUploadingAvatar,
              cacheGeneration: _avatarCacheGen,
              errorMessage: _avatarError,
              onTap: state.isUploadingAvatar ? null : _pickAvatar,
            ),
            Gap(AppSpacing.md.h),
            const FieldLabel('DISPLAY NAME'),
            Gap(AppSpacing.sm.h),
            JTextField(
              name: 'display_name',
              hint: 'Shown publicly to other users',
              initialValue: profile?.displayName ?? _metadataFullName,
              validator: FormBuilderValidators.required(
                errorText: 'Display name is required.',
              ),
            ),
            if (isTrade) ...[
              Gap(AppSpacing.md.h),
              const FieldLabel('LEGAL NAME'),
              Gap(AppSpacing.sm.h),
              JTextField(
                name: 'full_name',
                hint: 'For invoices and verification',
                initialValue: tp?.fullName ?? _metadataFullName,
                validator: FormBuilderValidators.required(
                  errorText: 'Legal name is required.',
                ),
              ),
            ],
            Gap(AppSpacing.sm.h),
          ],
        ),
      ),
    );
  }
}
