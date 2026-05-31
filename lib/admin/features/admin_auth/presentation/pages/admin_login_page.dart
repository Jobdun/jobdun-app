import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/design/widgets/j_button.dart';
import '../../../../../core/widgets/inputs/j_text_field.dart';
import '../../domain/entities/admin_session.dart';
import '../providers/admin_session_provider.dart';

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

    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: _AdminLoginCard(
              formKey: _formKey,
              errorMessage: _errorMessage,
              isLoading: isLoading,
              onSubmit: _submit,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminLoginCard extends StatelessWidget {
  const _AdminLoginCard({
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

    return Container(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: FormBuilder(
        key: formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            _BrandBlock(),
            const Gap(40),
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
              'Admin role required. Unauthorised sign-ins are signed out automatically.',
              textAlign: TextAlign.center,
              style: AdminText.caption(
                c.text3,
              ).copyWith(fontWeight: FontWeight.w500, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      children: [
        Text(
          'JOBDUN',
          textAlign: TextAlign.center,
          style: AdminText.display(c.text1).copyWith(letterSpacing: 4),
        ),
        const Gap(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: c.actionBg,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'ADMIN CONSOLE',
            style: AdminText.caption(
              c.actionTx,
            ).copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.5),
          ),
        ),
        const Gap(20),
        Text(
          'RESTRICTED ACCESS.',
          textAlign: TextAlign.center,
          style: AdminText.pageTitle(c.text1),
        ),
      ],
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
