import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../app/theme/app_colors.dart';

class FeatureScaffoldPage extends StatelessWidget {
  const FeatureScaffoldPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bullets,
  });

  final String title;
  final String subtitle;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            Gap(10.h),
            Text(subtitle),
            Gap(20.h),
            Card(
              child: Padding(
                padding: EdgeInsets.all(20.r),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: bullets
                      .map(
                        (item) => Padding(
                          padding: EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text('• $item'),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
