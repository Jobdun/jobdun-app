import 'package:flutter/material.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Admin review queue',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'This route is limited to the admin role in the starter router.',
            ),
            const SizedBox(height: 20),
            Row(
              children: const [
                Expanded(child: _AdminMetric(label: 'Pending verifications', value: '12')),
                SizedBox(width: 12),
                Expanded(child: _AdminMetric(label: 'Flagged jobs', value: '4')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminMetric extends StatelessWidget {
  const _AdminMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
