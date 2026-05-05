import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../../core/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;
  UserRole? _selectedRole;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _getStarted() {
    final role = _selectedRole;
    if (role == null) return;
    ref.read(authControllerProvider.notifier).completeOnboarding(role);
    // Router redirect handles navigation to /home when onboardingComplete flips true.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: const [
                  _WelcomePage(),
                  _RolePage(),
                ],
              ),
            ),
            _BottomBar(
              currentPage: _currentPage,
              selectedRole: _selectedRole,
              onRoleChanged: (role) => setState(() => _selectedRole = role),
              onNext: _next,
              onGetStarted: _getStarted,
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  const _WelcomePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.construction,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Welcome to ${AppConstants.appName}',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            AppConstants.appTagline,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Connect with verified builders and skilled trades. '
            'Post jobs, apply for work, and manage projects — all in one place.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5A5A5A),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _RolePage extends StatelessWidget {
  const _RolePage();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          Text(
            'What describes you best?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose your role to personalise your experience.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF5A5A5A),
            ),
          ),
          const SizedBox(height: 32),
          // Role cards are built by the parent via _BottomBar so they can
          // access onRoleChanged. We use a placeholder here; the real role
          // cards live in _BottomBar._RoleCards.
          const _RoleCardsPlaceholder(),
        ],
      ),
    );
  }
}

// Empty widget — role cards are owned by _BottomBar for state access.
class _RoleCardsPlaceholder extends StatelessWidget {
  const _RoleCardsPlaceholder();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentPage,
    required this.selectedRole,
    required this.onRoleChanged,
    required this.onNext,
    required this.onGetStarted,
  });

  final int currentPage;
  final UserRole? selectedRole;
  final ValueChanged<UserRole> onRoleChanged;
  final VoidCallback onNext;
  final VoidCallback onGetStarted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        children: [
          if (currentPage == 1) ...[
            _RoleCard(
              role: UserRole.builder,
              selected: selectedRole == UserRole.builder,
              onTap: () => onRoleChanged(UserRole.builder),
            ),
            const SizedBox(height: 12),
            _RoleCard(
              role: UserRole.trade,
              selected: selectedRole == UserRole.trade,
              onTap: () => onRoleChanged(UserRole.trade),
            ),
            const SizedBox(height: 24),
          ],
          // Dots indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: active
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          if (currentPage == 0)
            AppButton(label: 'Next', onPressed: onNext)
          else
            AppButton(
              label: 'Get Started',
              onPressed: selectedRole != null ? onGetStarted : null,
            ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: selected
                      ? theme.colorScheme.primaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  role == UserRole.builder
                      ? Icons.business_center_outlined
                      : Icons.construction_outlined,
                  color: selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      role.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF5A5A5A),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outlineVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
