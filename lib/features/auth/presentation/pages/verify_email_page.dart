import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class VerifyEmailPage extends ConsumerWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final email = authState.pendingVerificationEmail ?? '';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_outlined,
                  size: 48,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 32),
              Text('Check your inbox', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 12),
              Text(
                'We sent a verification link to',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5A5A5A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Click the link to verify your account, then come back and sign in.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5A5A5A),
                ),
                textAlign: TextAlign.center,
              ),
              if (authState.infoMessage != null) ...[
                const SizedBox(height: 20),
                _StatusBanner(
                  message: authState.infoMessage!,
                  isError: false,
                ),
              ],
              if (authState.errorMessage != null) ...[
                const SizedBox(height: 20),
                _StatusBanner(
                  message: authState.errorMessage!,
                  isError: true,
                ),
              ],
              const Spacer(),
              AppButton(
                label: authState.isLoading ? 'Sending...' : 'Resend verification email',
                variant: AppButtonVariant.secondary,
                onPressed: authState.isLoading
                    ? null
                    : () => ref
                        .read(authControllerProvider.notifier)
                        .resendVerificationEmail(),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: 'Back to sign in',
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).clearPendingVerification(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFCEAEA) : const Color(0xFFEAF4ED),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isError ? const Color(0xFFE7B5B5) : const Color(0xFFB7D4BE),
        ),
      ),
      child: Text(message, textAlign: TextAlign.center),
    );
  }
}
