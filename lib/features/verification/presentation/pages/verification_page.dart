import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_colors.dart';

class VerificationPage extends StatelessWidget {
  const VerificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg),
          children: [
            Text('Verification setup', style: tt.headlineMedium),
            Gap(12.h),
            const Text(
              'This screen is ready for licence, insurance, and identity document upload flows.',
            ),
            Gap(20.h),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Planned status pipeline', style: tt.headlineSmall),
                    Gap(12.h),
                    const Text('• Pending review'),
                    const Text('• Approved'),
                    const Text('• Rejected with reason'),
                    const Text('• Expiring soon'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
