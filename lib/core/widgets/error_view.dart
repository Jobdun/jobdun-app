import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../app/theme/app_colors.dart';
import '../errors/failures.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    this.failure,
    this.message,
    this.onRetry,
  }) : assert(failure != null || message != null);

  final Failure? failure;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = failure?.message ?? message!;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48.r, color: theme.colorScheme.error),
            Gap(AppSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              Gap(20.h),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
