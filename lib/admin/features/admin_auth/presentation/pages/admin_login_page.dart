import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../../../app/widgets/admin_brand.dart';
import '../../domain/entities/admin_session.dart';
import '../providers/admin_session_provider.dart';

/// Below this width the split collapses to a single centred column.
const double _splitBreakpoint = 880;

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormBuilderState>();
  String? _errorMessage;

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() => _errorMessage = null);

    final values = form.value;
    await ref
        .read(adminSessionProvider.notifier)
        .signIn(
          email: values['email'] as String,
          password: values['password'] as String,
        );

    if (!mounted) return;
    final state = ref.read(adminSessionProvider);
    state.whenOrNull(
      error: (error, _) {
        setState(() => _errorMessage = _humaniseError(error));
      },
    );
  }

  String _humaniseError(Object error) {
    if (error is NotAdminException) return error.message;
    if (error is AdminSignInException) return error.message;
    return 'Invalid email or password.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isLoading = ref.watch(adminSessionProvider).isLoading;

    final form = _SignInForm(
      formKey: _formKey,
      errorMessage: _errorMessage,
      isLoading: isLoading,
      onSubmit: _submit,
    );

    return Scaffold(
      backgroundColor: c.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _splitBreakpoint) {
            return _NarrowLayout(form: form);
          }
          // Brand panel left, sign-in right. The brand sits on the raised
          // surface layer so the two halves read as distinct without a rule.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Expanded(flex: 5, child: _BrandPanel()),
              Expanded(flex: 6, child: _FormPanel(child: form)),
            ],
          );
        },
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.border)),
      ),
      padding: const EdgeInsets.fromLTRB(56, 56, 56, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AdminBrandLockup(badgeSize: 48),
              const Gap(36),
              Text('RUN THE PLATFORM.', style: AdminText.display(c.text1)),
              const Gap(14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  'Verifications, user moderation, and platform health in one '
                  'console.',
                  style: AdminText.body(c.text2).copyWith(height: 1.6),
                ),
              ),
              const Gap(40),
              const _Capability(
                icon: AppIcons.verified,
                label: 'VERIFICATION QUEUE',
              ),
              const Gap(16),
              const _Capability(
                icon: AppIcons.applicantsOutline,
                label: 'USER MANAGEMENT',
              ),
              const Gap(16),
              const _Capability(
                icon: AppIcons.shield,
                label: 'AUDIT & SECURITY',
              ),
            ],
          ),
          Text(
            'RESTRICTED ACCESS · AUTHORISED ADMINS ONLY',
            style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Capability extends StatelessWidget {
  const _Capability({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Icon(icon, size: 18, color: c.text3),
        const Gap(12),
        Text(label, style: AdminText.label(c.text2)),
      ],
    );
  }
}

/// Right form panel — bare on `background` (no nested card; the panel is the
/// surface). Vertically centred, scrolls when the viewport is short.
class _FormPanel extends StatelessWidget {
  const _FormPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 48),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 96),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Stacked layout for narrow viewports: compact brand over a bordered form card.
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout({required this.form});

  final Widget form;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AdminBrandLockup(badgeSize: 40),
              const Gap(32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border),
                ),
                child: form,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.formKey,
    required this.errorMessage,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormBuilderState> formKey;
  final String? errorMessage;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return FormBuilder(
      key: formKey,
      autovalidateMode: AutovalidateMode.disabled,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('SIGN IN', style: AdminText.dialogTitle(c.text1)),
          const Gap(28),
          JTextField(
            name: 'email',
            label: 'EMAIL',
            hint: 'admin@jobdun.com.au',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(errorText: 'Email is required.'),
              FormBuilderValidators.email(errorText: 'Enter a valid email.'),
            ]),
          ),
          const Gap(16),
          JTextField(
            name: 'password',
            label: 'PASSWORD',
            hint: 'enter password',
            obscureText: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => isLoading ? null : onSubmit(),
            validator: FormBuilderValidators.required(
              errorText: 'Password is required.',
            ),
          ),
          if (errorMessage != null) ...[
            const Gap(16),
            _ErrorBanner(message: errorMessage!),
          ],
          const Gap(24),
          JButton(
            label: 'LOG IN',
            onPressed: isLoading ? null : onSubmit,
            isLoading: isLoading,
          ),
          const Gap(16),
          Text(
            'Unauthorised sign-ins are signed out automatically.',
            style: AdminText.caption(
              c.text3,
            ).copyWith(fontWeight: FontWeight.w500, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.urgentBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.urgent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: c.urgentTx, size: 18),
          const Gap(8),
          Expanded(
            child: Text(
              message,
              style: AdminText.labelMd(c.urgentTx).copyWith(letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}
