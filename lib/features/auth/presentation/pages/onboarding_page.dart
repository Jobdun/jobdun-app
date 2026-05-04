import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  UserRole? _selectedRole;

  void _finishSetup() {
    final role = _selectedRole;
    if (role == null) {
      return;
    }

    ref.read(authControllerProvider.notifier).completeOnboarding(role);
    context.go(role == UserRole.admin ? '/admin' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose your role', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'This basic setup gives you the first mobile flow for Android. You can wire real auth and profile persistence next.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF5A5A5A),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: UserRole.values.map((role) {
                    final selected = role == _selectedRole;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: BorderSide(
                            color: selected
                                ? Theme.of(context).colorScheme.primary
                                : const Color(0xFFE2D6C8),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => setState(() => _selectedRole = role),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        role.label,
                                        style: theme.textTheme.titleLarge,
                                      ),
                                    ),
                                    Icon(
                                      selected
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(role.description),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              AppButton(label: 'Finish setup', onPressed: _finishSetup),
            ],
          ),
        ),
      ),
    );
  }
}
