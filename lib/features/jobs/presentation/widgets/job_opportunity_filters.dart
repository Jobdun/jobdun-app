import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../domain/entities/job.dart';
import '../providers/jobs_provider.dart';

class JobOpportunityFilters extends ConsumerWidget {
  const JobOpportunityFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(jobsControllerProvider.select((s) => s.filter));
    final controller = ref.read(jobsControllerProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GvChip(
            label: 'ALL JOBS',
            active:
                filter?.jobKind == null && filter?.openToApprentices == null,
            onTap: () {
              controller.filterOpportunities();
            },
          ),
          Gap(8.w),
          GvChip(
            label: 'APPRENTICESHIPS',
            active: filter?.jobKind == JobKind.apprenticeship,
            onTap: () {
              controller.filterOpportunities(jobKind: JobKind.apprenticeship);
            },
          ),
          Gap(8.w),
          GvChip(
            label: 'OPEN TO APPRENTICES',
            active: filter?.openToApprentices == true,
            onTap: () {
              controller.filterOpportunities(openToApprentices: true);
            },
          ),
        ],
      ),
    );
  }
}
