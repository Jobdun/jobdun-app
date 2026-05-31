import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';
import 'onboarding_avatar_step.dart';
import 'onboarding_name_step.dart';
import 'onboarding_progress_row.dart';
import 'onboarding_role_step.dart';

/// Single, non-dismissible sheet that finishes a signup. Replaces the older
/// `RoleSelectionSheet`, which only captured the role. The three steps are:
///
///   1. Role pick  — always shown when `auth.role == null`
///   2. Confirm name — shown when display_name is null OR (for SSO/phone)
///      always shown so users see what we captured and can edit it
///   3. Optional avatar — shown when profiles.avatar_url is null; can SKIP
///
/// Pre-fill on step 2 + step 3 comes from `profileControllerProvider.profile`,
/// which after Phase 1 carries the Google name + picture even for users who
/// signed up before the trigger was fixed (the one-shot backfill caught
/// existing rows).
///
/// Layout: PageView with progress dots. Back arrow on steps 2/3 to revise an
/// earlier choice. Non-dismissible via PopScope until `_onFinish` resolves —
/// matches the previous role sheet's lock.
class OnboardingCompletionSheet extends ConsumerStatefulWidget {
  const OnboardingCompletionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showJSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (_) => const OnboardingCompletionSheet(),
    );
  }

  @override
  ConsumerState<OnboardingCompletionSheet> createState() =>
      _OnboardingCompletionSheetState();
}

class _OnboardingCompletionSheetState
    extends ConsumerState<OnboardingCompletionSheet> {
  final _pageController = PageController();
  final _nameController = TextEditingController();

  int _step = 0; // 0 = role, 1 = name, 2 = avatar
  UserRole? _role;
  File? _pickedAvatar;
  bool _submitting = false;
  String? _errorMessage;
  DateTime _stepEnteredAt = DateTime.now();
  final DateTime _openedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    final profile = ref.read(profileControllerProvider).profile;
    _role = auth.role;
    // Pre-fill name from profile (which after Phase 1 reflects whatever the
    // auth provider supplied). Falls back to the email-derived name only on
    // step 2 render, not here, so the user sees an empty field when we
    // really have nothing — clearer signal than "your @gmail.com" as a name.
    final cachedName = profile?.displayName?.trim() ?? '';
    if (cachedName.isNotEmpty) {
      _nameController.text = cachedName;
    }
    // Skip ahead: if role + name are already populated, jump to avatar step.
    // The sheet wouldn't normally open in that state (home page gate checks
    // both) but a race or stale watch could send us here.
    final hasRole = _role != null;
    final hasName = cachedName.isNotEmpty;
    if (hasRole && hasName) {
      _step = 2;
    } else if (hasRole) {
      _step = 1;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _step > 0) _pageController.jumpToPage(_step);
    });
    AuthAnalytics.completionSheetOpened(startingStep: _step);
  }

  static const _stepNames = ['role', 'name', 'avatar'];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goToStep(int step) {
    final previousStep = _step;
    final msOnStep = DateTime.now().difference(_stepEnteredAt).inMilliseconds;
    if (previousStep >= 0 && previousStep < _stepNames.length) {
      AuthAnalytics.completionStep(
        step: _stepNames[previousStep],
        skipped: false,
        msOnStep: msOnStep,
      );
    }
    setState(() {
      _step = step;
      _errorMessage = null;
      _stepEnteredAt = DateTime.now();
    });
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> _onPickRole(UserRole role) async {
    setState(() => _role = role);
    // Give a brief beat for the optimistic highlight before advancing.
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _goToStep(1);
  }

  Future<void> _pickAvatar(ImageSource source) async {
    try {
      final file = await ImageUploadService.pickCropCompress(
        source: source,
        aspect: ImageAspect.square,
      );
      if (!mounted || file == null) return;
      setState(() => _pickedAvatar = file);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    }
  }

  Future<void> _onFinish({required bool skipAvatar}) async {
    final role = _role;
    final name = _nameController.text.trim();
    if (role == null || name.isEmpty) {
      setState(() => _errorMessage = 'Tell us your name to finish.');
      return;
    }
    setState(() {
      _submitting = true;
      _errorMessage = null;
    });
    final authNotifier = ref.read(authControllerProvider.notifier);
    final ok = await authNotifier.completeOnboarding(
      role: role,
      displayName: name,
    );
    if (!ok || !mounted) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _errorMessage =
              ref.read(authControllerProvider).errorMessage ??
              "Couldn't save — try again.";
        });
      }
      return;
    }
    // Avatar (optional) uploads after role+name so the AuthController state
    // is settled first. Failure here doesn't roll back — the user has
    // completed the critical bits and can re-pick a photo from /profile/edit.
    if (!skipAvatar && _pickedAvatar != null) {
      final profileNotifier = ref.read(profileControllerProvider.notifier);
      await profileNotifier.uploadAvatar(_pickedAvatar!);
    }
    AuthAnalytics.completionStep(
      step: 'avatar',
      skipped: skipAvatar || _pickedAvatar == null,
      msOnStep: DateTime.now().difference(_stepEnteredAt).inMilliseconds,
    );
    final provider = _inferProvider();
    AuthAnalytics.signupCompleted(
      provider: provider,
      totalMs: DateTime.now().difference(_openedAt).inMilliseconds,
    );
    if (!mounted) return;
    // Refresh profile so display_name + avatar populate immediately.
    await ref.read(profileControllerProvider.notifier).loadProfile();
    if (mounted) Navigator.of(context).pop();
  }

  /// Best-effort attribution of which provider got the user this far. The
  /// signupStarted event on /login carries the provider explicitly; we
  /// recover it here from auth.users.app_metadata.provider so the funnel
  /// joins end-to-end without threading state through the router.
  String _inferProvider() {
    final user = ref.read(authControllerProvider).email;
    // app_metadata.provider lives on the auth.users row, accessible via the
    // Supabase Dart client. Falling back to 'unknown' is fine — analytics-
    // only attribution, never gates UX.
    return user == null ? 'unknown' : 'email_or_sso';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return PopScope(
      canPop: false,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppRadius.card.r),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg.w,
            AppSpacing.md.h,
            AppSpacing.lg.w,
            AppSpacing.xl.h + viewInsets,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OnboardingProgressRow(step: _step),
              Gap(AppSpacing.lg.h),
              SizedBox(
                height: 460.h,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    OnboardingRoleStep(
                      selected: _role,
                      disabled: _submitting,
                      onPick: _onPickRole,
                    ),
                    OnboardingNameStep(
                      controller: _nameController,
                      role: _role,
                      onBack: () => _goToStep(0),
                      onContinue: () {
                        if (_nameController.text.trim().isEmpty) {
                          setState(
                            () => _errorMessage = 'Enter a name to continue.',
                          );
                          return;
                        }
                        _goToStep(2);
                      },
                    ),
                    OnboardingAvatarStep(
                      pickedFile: _pickedAvatar,
                      name: _nameController.text,
                      submitting: _submitting,
                      onBack: () => _goToStep(1),
                      onCamera: () => _pickAvatar(ImageSource.camera),
                      onGallery: () => _pickAvatar(ImageSource.gallery),
                      onSkip: () => _onFinish(skipAvatar: true),
                      onFinish: () => _onFinish(skipAvatar: false),
                    ),
                  ],
                ),
              ),
              if (_errorMessage != null) ...[
                Gap(AppSpacing.sm.h),
                Text(
                  _errorMessage!,
                  style: tt.bodySmall!.copyWith(color: c.urgent),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
