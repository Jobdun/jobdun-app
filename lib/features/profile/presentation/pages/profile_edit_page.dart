import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({super.key});

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _displayNameCtrl = TextEditingController();
  final _suburbCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _abnCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profileState = ref.read(profileControllerProvider);
    _displayNameCtrl.text = profileState.profile?.displayName ?? '';
    final bp = profileState.builderProfile;
    final tp = profileState.tradeProfile;
    if (bp != null) {
      _companyCtrl.text = bp.companyName;
      _abnCtrl.text = bp.abn ?? '';
      _suburbCtrl.text = bp.serviceSuburb ?? '';
      _stateCtrl.text = bp.serviceState ?? '';
      _phoneCtrl.text = bp.contactPhone ?? '';
    } else if (tp != null) {
      _displayNameCtrl.text = tp.fullName;
      _suburbCtrl.text = tp.baseSuburb ?? '';
      _stateCtrl.text = tp.baseState ?? '';
      _aboutCtrl.text = tp.about ?? '';
    }
  }

  @override
  void dispose() {
    _displayNameCtrl.dispose();
    _suburbCtrl.dispose();
    _stateCtrl.dispose();
    _aboutCtrl.dispose();
    _companyCtrl.dispose();
    _abnCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context, JColors c) async {
    final tt = Theme.of(context).textTheme;
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _isSaving = false);
    router.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Iconsax.tick_circle, size: 18.r, color: Colors.white), // intentional: white-on-action
            Gap(10.w),
            Text(
              'Profile updated.',
              style: tt.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white, // intentional: white-on-action
              ),
            ),
          ],
        ),
        backgroundColor: c.verified,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final isBuilder = authState.role == UserRole.builder;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Iconsax.arrow_left, size: 22.r, color: c.text1),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'EDIT PROFILE',
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.12 * 11,
                            color: c.text3,
                          ),
                        ),
                        Gap(2.h),
                        Text(
                          'Your details',
                          style: tt.headlineSmall!.copyWith(
                            fontSize: 22.sp,
                            fontWeight: FontWeight.w700,
                            color: c.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.lg.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBuilder) ...[
                      _FieldLabel('COMPANY NAME'),
                      Gap(AppSpacing.sm.h),
                      _InputField(controller: _companyCtrl, hint: 'e.g. Pinnacle Construct'),
                      Gap(AppSpacing.md.h),
                      _FieldLabel('ABN'),
                      Gap(AppSpacing.sm.h),
                      _InputField(controller: _abnCtrl, hint: '12 345 678 901', keyboardType: TextInputType.number),
                      Gap(AppSpacing.md.h),
                    ] else ...[
                      _FieldLabel('FULL NAME'),
                      Gap(AppSpacing.sm.h),
                      _InputField(controller: _displayNameCtrl, hint: 'Your full name'),
                      Gap(AppSpacing.md.h),
                    ],
                    _FieldLabel('DISPLAY NAME'),
                    Gap(AppSpacing.sm.h),
                    _InputField(controller: _displayNameCtrl, hint: 'How you appear in the app'),
                    Gap(AppSpacing.md.h),
                    _FieldLabel('BASE ${isBuilder ? 'SERVICE' : ''} SUBURB'),
                    Gap(AppSpacing.sm.h),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: _InputField(controller: _suburbCtrl, hint: 'Suburb'),
                        ),
                        Gap(10.w),
                        Expanded(
                          flex: 2,
                          child: _InputField(controller: _stateCtrl, hint: 'State'),
                        ),
                      ],
                    ),
                    Gap(AppSpacing.md.h),
                    _FieldLabel('CONTACT PHONE'),
                    Gap(AppSpacing.sm.h),
                    _InputField(
                      controller: _phoneCtrl,
                      hint: '+61 4 1234 5678',
                      keyboardType: TextInputType.phone,
                    ),
                    Gap(AppSpacing.md.h),
                    _FieldLabel('ABOUT'),
                    Gap(AppSpacing.sm.h),
                    Container(
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(AppRadius.input.r),
                        border: Border.all(color: c.border),
                      ),
                      child: TextField(
                        controller: _aboutCtrl,
                        maxLines: 4,
                        style: tt.bodyLarge!.copyWith(color: c.text1),
                        decoration: InputDecoration(
                          hintText: isBuilder
                              ? 'Tell tradies about your company…'
                              : 'Tell builders about your experience…',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.all(14.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Save button
            Container(
              decoration: BoxDecoration(
                color: c.card,
                border: Border(top: BorderSide(color: c.border)),
              ),
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
              child: GestureDetector(
                onTap: _isSaving ? null : () => _save(context, c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: double.infinity,
                  height: 48.h,
                  decoration: BoxDecoration(
                    color: _isSaving ? c.surfaceRaised : c.action,
                    borderRadius: BorderRadius.circular(AppRadius.btn.r),
                  ),
                  alignment: Alignment.center,
                  child: _isSaving
                      ? SizedBox(
                          width: 20.r,
                          height: 20.r,
                          child: CircularProgressIndicator(color: c.text1, strokeWidth: 2),
                        )
                      : Text(
                          'SAVE CHANGES',
                          style: tt.titleMedium!.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.white, // intentional: white-on-action
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelSmall!.copyWith(
      letterSpacing: 0.12 * 11,
      color: context.c.text3,
    ),
  );
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hint,
    this.keyboardType,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.input.r),
        border: Border.all(color: c.border),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: Theme.of(context).textTheme.bodyLarge!.copyWith(color: c.text1),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          isDense: true,
        ),
      ),
    );
  }
}
