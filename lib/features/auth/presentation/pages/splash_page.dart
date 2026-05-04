import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../core/config/env.dart';
import '../providers/auth_provider.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  Timer? _startupTimer;

  @override
  void initState() {
    super.initState();
    _startupTimer = Timer(const Duration(milliseconds: 900), _continue);
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    super.dispose();
  }

  void _continue() {
    if (!mounted) {
      return;
    }

    final authState = ref.read(authControllerProvider);

    if (!authState.isAuthenticated) {
      context.go('/login');
      return;
    }

    if (!authState.onboardingComplete) {
      context.go('/onboarding');
      return;
    }

    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1F2A2F), Color(0xFFB8561C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  AppConstants.appName,
                  style: theme.textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppConstants.appTagline,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: const Color(0xFFFFE4D0),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.appDescription,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFFF9F0E8),
                  ),
                ),
                const Spacer(),
                _EnvStatusChip(
                  configured: AppEnv.isSupabaseConfigured,
                  missingKeys: AppEnv.missingKeysSummary,
                ),
                const SizedBox(height: 20),
                const LinearProgressIndicator(
                  minHeight: 6,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EnvStatusChip extends StatelessWidget {
  const _EnvStatusChip({
    required this.configured,
    required this.missingKeys,
  });

  final bool configured;
  final String missingKeys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(
            configured ? Icons.check_circle_outline : Icons.info_outline,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              configured
                  ? 'Supabase auth is configured and ready for sign-in.'
                  : 'Supabase auth is already built, but this run is missing $missingKeys. Launch with --dart-define-from-file=.env.',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
