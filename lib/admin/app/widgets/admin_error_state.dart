import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/design/widgets/j_button.dart';

/// Shared admin error state — icon + title + message + a single RETRY action.
/// Replaces the four ad-hoc "COULDN'T LOAD …" + bare `TextButton` blocks that
/// each list page used to roll on its own, so a failed load looks identical
/// everywhere in the console.
class AdminErrorState extends StatelessWidget {
  const AdminErrorState({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 40, color: c.urgent),
              const Gap(12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AdminText.sectionTitle(
                  c.text1,
                ).copyWith(letterSpacing: 0.5),
              ),
              const Gap(8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AdminText.meta(c.text2),
              ),
              const Gap(20),
              SizedBox(
                width: 180,
                child: JButton(
                  label: 'RETRY',
                  variant: JButtonVariant.secondary,
                  size: JButtonSize.compact,
                  onPressed: onRetry,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
