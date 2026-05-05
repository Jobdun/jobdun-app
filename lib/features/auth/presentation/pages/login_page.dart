import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../core/config/env.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../providers/auth_provider.dart';
import '../widgets/social_auth_buttons.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: 'demo@jobdun.app');
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(authControllerProvider.notifier).signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Welcome back to ${AppConstants.appName}',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                'Supabase authentication is already live. Sign in to review jobs, messages, and verification progress from Android first.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5A5A5A),
                ),
              ),
              const SizedBox(height: 28),
              if (!AppEnv.isSupabaseConfigured) ...[
                _SetupNotice(missingKeys: AppEnv.missingKeysSummary),
                const SizedBox(height: 20),
              ],
              const _AuthHighlightCard(),
              const SizedBox(height: 24),
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
                _StatusMessage(
                  message: authState.errorMessage!,
                  backgroundColor: const Color(0xFFFCEAEA),
                  borderColor: const Color(0xFFE7B5B5),
                ),
              ],
              if (authState.infoMessage != null) ...[
                const SizedBox(height: 16),
                _StatusMessage(
                  message: authState.infoMessage!,
                  backgroundColor: const Color(0xFFEAF4ED),
                  borderColor: const Color(0xFFB7D4BE),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: authState.isLoading ? 'Signing in...' : 'Sign in',
                onPressed: authState.isLoading ? null : _continue,
              ),
              const SizedBox(height: 24),
              const SocialAuthButtons(),
              const SizedBox(height: 24),
              AppButton(
                label: 'Create an account',
                variant: AppButtonVariant.secondary,
                onPressed:
                    authState.isLoading ? null : () => context.go('/register'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: AppButton(
                  label: 'Forgot password',
                  variant: AppButtonVariant.text,
                  onPressed: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthHighlightCard extends StatelessWidget {
  const _AuthHighlightCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Supabase auth is working',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 10),
            Text('1. Sign in or create an account'),
            Text('2. Supabase handles the email/password session'),
            Text('3. Continue into onboarding and the dashboard'),
          ],
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.missingKeys});

  final String missingKeys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8C9B3)),
      ),
      child: Text(
        'Supabase auth is implemented, but this run is missing $missingKeys. Start the app with --dart-define-from-file=.env.',
      ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  const _StatusMessage({
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
