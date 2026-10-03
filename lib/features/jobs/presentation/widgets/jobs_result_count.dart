import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import '../../../../core/design/colors.dart';
import '../../domain/entities/job.dart';

/// Listen to pagination itself: errors, refreshes and appended pages do not
/// necessarily change the surrounding Riverpod state.
class JobsResultCount extends StatelessWidget {
  const JobsResultCount({super.key, required this.controller});

  final PagingController<int, Job> controller;

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<PagingState<int, Job>>(
        valueListenable: controller,
        builder: (context, state, _) {
          final items = state.itemList;
          if (items == null || state.error != null) {
            return const SizedBox.shrink();
          }
          final count = items.length;
          final more = state.nextPageKey != null && count > 0 ? '+' : '';
          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              12.h,
              AppSpacing.md.w,
              4.h,
            ),
            child: Text(
              '$count$more ${count == 1 ? 'job' : 'jobs'} found',
              style: Theme.of(context).textTheme.labelMedium!.copyWith(
                fontWeight: FontWeight.w400,
                color: context.c.text3,
              ),
            ),
          );
        },
      );
}
