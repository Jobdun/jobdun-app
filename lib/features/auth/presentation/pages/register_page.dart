import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
        )
        .then((success) {
          if (!mounted || !success) {
            return;
          }
          context.go('/onboarding');
        });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create your account', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Create an email/password account through Supabase Auth. If your project requires email confirmation, you will need to verify the address before signing in.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5A5A5A),
                ),
              ),
              const SizedBox(height: 28),
              AppTextField(
                label: 'Full name or company name',
                controller: _nameController,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 16),
                _RegisterStatusMessage(
                  message: authState.errorMessage!,
                  backgroundColor: const Color(0xFFFCEAEA),
                  borderColor: const Color(0xFFE7B5B5),
                ),
              ],
              if (authState.infoMessage != null) ...[
                const SizedBox(height: 16),
                _RegisterStatusMessage(
                  message: authState.infoMessage!,
                  backgroundColor: const Color(0xFFEAF4ED),
                  borderColor: const Color(0xFFB7D4BE),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: authState.isLoading ? 'Creating account...' : 'Continue',
                onPressed: authState.isLoading ? null : _continue,
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to sign in',
                variant: AppButtonVariant.text,
                onPressed:
                    authState.isLoading ? null : () => context.go('/login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegisterStatusMessage extends StatelessWidget {
  const _RegisterStatusMessage({
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String message;
  final Color backgroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Text(message),
    );
  }
}
