import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/services/auth_analytics.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../core/widgets/social_auth_button.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../../legal/presentation/widgets/legal_acceptance_checkbox.dart';
import '../providers/auth_provider.dart';

part 'register_page_role_step.dart';
part 'register_page_form_step.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key, this.initialRole});

  // When set (via /register?role=…), step 1 is skipped — the user already
  // chose on /login. The form shows a CHANGE chip so a misclick is fixable.
  final UserRole? initialRole;

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  int _step = 1;
  UserRole? _selectedRole;

  final _formKey = GlobalKey<FormBuilderState>();
  bool _ready = false;
  String _passwordValue = '';
  bool _termsAccepted = false;
  bool _showTermsError = false;

  @override
  void initState() {
    super.initState();
    // Priority order for initial role:
    //   1. registerDraft.role — user bounced back from /verify-email
    //   2. widget.initialRole — entered via /register?role=…
    //   3. null — show step 1 picker
    final draft = ref.read(authControllerProvider).registerDraft;
    if (draft != null) {
      _selectedRole = draft.role;
      _step = 2;
    } else if (widget.initialRole != null) {
      _selectedRole = widget.initialRole;
      _step = 2;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _ready = true);
    });
  }

  void _pickRole(UserRole role) {
    // Tap-to-advance: no Continue button. Card tap = step 1 done.
    setState(() {
      _selectedRole = role;
      _step = 2;
    });
  }

  void _goBackToPicker() {
    setState(() => _step = 1);
  }

  void _onGoogle() {
    AuthAnalytics.ssoTapped(provider: 'google');
    ref.read(authControllerProvider.notifier).signInWithGoogle();
  }

  void _onApple() {
    AuthAnalytics.ssoTapped(provider: 'apple');
    ref.read(authControllerProvider.notifier).signInWithApple();
  }

  void _onPhone() {
    AuthAnalytics.phoneTapped();
    context.push('/phone-auth');
  }

  void _submit() {
    final formValid = _formKey.currentState?.saveAndValidate() ?? false;
    if (!_termsAccepted) {
      setState(() => _showTermsError = true);
    }
    if (!formValid || !_termsAccepted) return;
    final values = _formKey.currentState!.value;

    // Phone deferred: collected just-in-time when a Trade applies to a job
    // or a Builder posts their first job (T1.1 friction reduction sprint).
    // Marketing opt-in deferred: asked via day-3 in-app prompt — AU Spam Act
    // consent is more informed once the user has seen the product.
    ref
        .read(authControllerProvider.notifier)
        .register(
          email: values['email'] as String,
          password: values['password'] as String,
          fullName: values['full_name'] as String,
          role: _selectedRole,
        );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: AnimatedOpacity(
          opacity: _ready ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          child: Column(
            children: [
              // ── Top bar — back arrow only when we have somewhere to go ────
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg.w,
                  vertical: 10.h,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step == 2 && widget.initialRole == null) {
                          // User picked role inline — back returns to picker.
                          _goBackToPicker();
                        } else {
                          // Pre-picked from /login or already on step 1 —
                          // back exits the whole flow.
                          context.go('/login');
                        }
                      },
                      icon: Icon(
                        AppIcons.back,
                        color: c.text1,
                        size: AppIconSize.md.r,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: BoxConstraints(
                        minWidth: 40.r,
                        minHeight: 40.r,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // ── Step content ──────────────────────────────────────────────
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: _step == 1
                      ? _RoleStep(
                          key: const ValueKey(1),
                          selectedRole: _selectedRole,
                          onRolePicked: _pickRole,
                          onGoToLogin: () => context.go('/login'),
                          onGoogle: _onGoogle,
                          onApple: _onApple,
                          onPhone: _onPhone,
                          isBusy: authState.isLoading,
                          c: c,
                          tt: tt,
                        )
                      : _FormStep(
                          key: const ValueKey(2),
                          role: _selectedRole!,
                          formKey: _formKey,
                          authState: authState,
                          draft: authState.registerDraft,
                          passwordValue: _passwordValue,
                          termsAccepted: _termsAccepted,
                          showTermsError: _showTermsError,
                          // CHANGE chip — let the user fix a misclick.
                          // When initialRole was supplied via deep-link, go
                          // back to the picker rather than just /login so
                          // they can flip role without losing the funnel.
                          onChangeRole: _goBackToPicker,
                          onTermsChanged: (v) => setState(() {
                            _termsAccepted = v;
                            if (v) _showTermsError = false;
                          }),
                          onPasswordChanged: (v) =>
                              setState(() => _passwordValue = v ?? ''),
                          onSubmit: authState.isLoading ? null : _submit,
                          onGoToLogin: () => context.go('/login'),
                          c: c,
                          tt: tt,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
