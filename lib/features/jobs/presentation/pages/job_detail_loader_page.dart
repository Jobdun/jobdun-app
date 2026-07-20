import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/theme/app_icons.dart';
import '../providers/jobs_provider.dart';
import 'job_detail_page.dart';

/// Renders `/jobs/:id` when no [JobDetailArgs] extra was provided — deep
/// links and the post-auth return from a guest gate. Fetches the job (the
/// datasource reads the public view for guests) and hands off to the same
/// [JobDetailPage] the in-app navigation uses.
class JobDetailLoaderPage extends ConsumerWidget {
  const JobDetailLoaderPage({super.key, required this.jobId});

  final String jobId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final asyncJob = ref.watch(jobByIdProvider(jobId));

    return asyncJob.when(
      data: (job) => JobDetailPage(args: JobDetailArgs.fromJob(job)),
      loading: () => Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
            child: JSkeletonList(
              enabled: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loading job title placeholder', style: tt.titleLarge),
                  Gap(16.h),
                  Text(
                    'Placeholder line for the job description block '
                    'while the listing loads from the feed.',
                    style: tt.bodyLarge,
                  ),
                  Gap(12.h),
                  Text(
                    'Second placeholder line for location and budget.',
                    style: tt.bodyLarge,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  AppIcons.warning,
                  size: AppIconSize.hero.r,
                  color: c.text3,
                ),
                Gap(12.h),
                Text(
                  "This job isn't available",
                  textAlign: TextAlign.center,
                  style: tt.titleLarge!.copyWith(color: c.text1),
                ),
                Gap(6.h),
                Text(
                  'It may have been filled or removed.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                ),
                Gap(20.h),
                JButton(
                  label: 'TRY AGAIN',
                  onPressed: () => ref.invalidate(jobByIdProvider(jobId)),
                ),
                Gap(10.h),
                JButton(
                  label: 'BACK',
                  variant: JButtonVariant.secondary,
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
