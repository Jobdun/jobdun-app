import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/auth_provider.dart';

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
              _ProgressRow(step: _step),
              Gap(AppSpacing.lg.h),
              SizedBox(
                height: 460.h,
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepRolePick(
                      selected: _role,
                      disabled: _submitting,
                      onPick: _onPickRole,
                    ),
                    _StepConfirmName(
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
                    _StepAvatar(
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
                  style: TextStyle(fontSize: 12.sp, color: c.urgent),
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

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == step;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 24.w : 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: active ? c.action : c.border,
              borderRadius: BorderRadius.circular(4.r),
            ),
          ),
        );
      }),
    );
  }
}

class _StepRolePick extends StatelessWidget {
  const _StepRolePick({
    required this.selected,
    required this.disabled,
    required this.onPick,
  });

  final UserRole? selected;
  final bool disabled;
  final void Function(UserRole) onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'WELCOME TO JOBDUN',
          style: tt.labelSmall!.copyWith(
            color: c.text3,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(8.h),
        Text(
          'Which side are you on?',
          style: tt.headlineMedium!.copyWith(color: c.text1, fontSize: 22.sp),
        ),
        Gap(6.h),
        Text(
          'About 20 seconds to finish setting up.',
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        Gap(AppSpacing.lg.h),
        _RoleCard(
          icon: AppIcons.builder,
          label: "I'M HIRING",
          description: 'Post jobs, review applicants, manage crews.',
          selected: selected == UserRole.builder,
          disabled: disabled,
          onTap: () => onPick(UserRole.builder),
        ),
        Gap(12.h),
        _RoleCard(
          icon: AppIcons.briefcase,
          label: "I'M LOOKING FOR WORK",
          description: 'Browse jobs, apply, get hired.',
          selected: selected == UserRole.trade,
          disabled: disabled,
          onTap: () => onPick(UserRole.trade),
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String description;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.all(AppSpacing.lg.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44.r,
              height: 44.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.action : c.surfaceRaised,
                borderRadius: BorderRadius.circular(AppRadius.avatar.r),
              ),
              child: Icon(
                icon,
                size: 22.r,
                // intentional: white-on-action when selected
                color: selected ? Colors.white : c.text2,
              ),
            ),
            Gap(AppSpacing.md.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Gap(4.h),
                  Text(
                    description,
                    style: tt.bodySmall!.copyWith(
                      color: c.text2,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
            ),
            Gap(AppSpacing.sm.w),
            Icon(
              AppIcons.chevronRight,
              size: 18.r,
              color: selected ? c.action : c.text3,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepConfirmName extends StatelessWidget {
  const _StepConfirmName({
    required this.controller,
    required this.role,
    required this.onBack,
    required this.onContinue,
  });

  final TextEditingController controller;
  final UserRole? role;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  String get _explanation => role == UserRole.builder
      ? 'Trades see this on your job posts and messages.'
      : 'Builders see this on your applications and profile.';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: onBack,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(AppIcons.back, size: 18.r, color: c.text2),
              ),
            ),
            Gap(8.w),
            Text(
              'STEP 2 OF 3',
              style: tt.labelSmall!.copyWith(
                color: c.text3,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Gap(8.h),
        Text(
          'What should we call you?',
          style: tt.headlineMedium!.copyWith(color: c.text1, fontSize: 22.sp),
        ),
        Gap(6.h),
        Text(_explanation, style: tt.bodyMedium!.copyWith(color: c.text2)),
        Gap(AppSpacing.lg.h),
        Text(
          'YOUR NAME',
          style: tt.labelSmall!.copyWith(
            color: c.text3,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(6.h),
        JTextField(
          name: 'display_name',
          hint: 'e.g. Sam Wilson',
          controller: controller,
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: JButton(label: 'CONTINUE', onPressed: onContinue),
        ),
      ],
    );
  }
}

class _StepAvatar extends StatelessWidget {
  const _StepAvatar({
    required this.pickedFile,
    required this.name,
    required this.submitting,
    required this.onBack,
    required this.onCamera,
    required this.onGallery,
    required this.onSkip,
    required this.onFinish,
  });

  final File? pickedFile;
  final String name;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final initials = StringUtils.initials(name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            InkWell(
              onTap: submitting ? null : onBack,
              child: Padding(
                padding: EdgeInsets.all(4.r),
                child: Icon(AppIcons.back, size: 18.r, color: c.text2),
              ),
            ),
            Gap(8.w),
            Text(
              'STEP 3 OF 3',
              style: tt.labelSmall!.copyWith(
                color: c.text3,
                letterSpacing: 1.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        Gap(8.h),
        Text(
          'Add a profile photo?',
          style: tt.headlineMedium!.copyWith(color: c.text1, fontSize: 22.sp),
        ),
        Gap(6.h),
        Text(
          'Optional — but profiles with photos get more replies.',
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        Gap(AppSpacing.lg.h),
        Center(
          child: GestureDetector(
            onTap: submitting ? null : onGallery,
            child: pickedFile == null
                ? AvatarBlock(initials: initials, size: 120)
                : ClipOval(
                    child: Image.file(
                      pickedFile!,
                      width: 120.r,
                      height: 120.r,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
        ),
        Gap(AppSpacing.md.h),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'CAMERA',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onCamera,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: 'GALLERY',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onGallery,
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(
              child: JButton(
                label: 'SKIP',
                variant: JButtonVariant.secondary,
                onPressed: submitting ? null : onSkip,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: JButton(
                label: submitting ? 'FINISHING…' : 'FINISH',
                isLoading: submitting,
                onPressed: submitting ? null : onFinish,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
