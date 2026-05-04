import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/constants/app_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final role = authState.role;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).signOut();
              if (!context.mounted) {
                return;
              }
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Android starter dashboard',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              role == null
                  ? 'No role selected yet.'
                  : 'Signed in as ${role.label}. This is the base screen set for the first mobile setup.',
            ),
            const SizedBox(height: 24),
            const _StatusStrip(),
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickLinkCard(
                  title: 'Jobs',
                  subtitle: 'Browse and manage open work',
                  icon: Icons.work_outline,
                  onTap: () => context.go('/jobs'),
                ),
                _QuickLinkCard(
                  title: 'Messages',
                  subtitle: 'Job-specific conversations',
                  icon: Icons.forum_outlined,
                  onTap: () => context.go('/messages'),
                ),
                _QuickLinkCard(
                  title: 'Profile',
                  subtitle: 'Identity, company, and reviews',
                  icon: Icons.badge_outlined,
                  onTap: () => context.go('/profile'),
                ),
                _QuickLinkCard(
                  title: 'Verification',
                  subtitle: 'Licences and insurance tracking',
                  icon: Icons.verified_user_outlined,
                  onTap: () => context.go('/verification'),
                ),
                if (role == UserRole.admin)
                  _QuickLinkCard(
                    title: 'Admin',
                    subtitle: 'Moderation and review queue',
                    icon: Icons.admin_panel_settings_outlined,
                    onTap: () => context.go('/admin'),
                  ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/home');
            case 1:
              context.go('/jobs');
            case 2:
              context.go('/messages');
            case 3:
              context.go('/profile');
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.work_outline), label: 'Jobs'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _MetricTile(label: 'Open jobs', value: '24'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: 'Unread', value: '7'),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _MetricTile(label: 'Checks', value: '3'),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  const _QuickLinkCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.of(context).size.width - 52) / 2;

    return SizedBox(
      width: width,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(subtitle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
