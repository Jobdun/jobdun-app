import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../verification/presentation/widgets/unverified_consent_dialog.dart';
import '../../domain/entities/job_application.dart';
import '../providers/applications_provider.dart';
import 'job_applicants_args.dart';

export 'job_applicants_args.dart';

part 'job_applicants_widgets.dart';

/// Builder-facing "applicants for this job" screen (layout A): the job summary
/// pinned on top + a scannable list of the people who applied. Tapping a row
/// opens the applicant detail. Scoped to one job via [JobApplicantsArgs.jobId];
/// applicants come from the builder's loaded incoming list, filtered here.
class JobApplicantsPage extends ConsumerStatefulWidget {
  const JobApplicantsPage({super.key, required this.args});

  final JobApplicantsArgs args;

  @override
  ConsumerState<JobApplicantsPage> createState() => _JobApplicantsPageState();
}

class _JobApplicantsPageState extends ConsumerState<JobApplicantsPage> {
  // The builder's incoming applications are loaded by the controller's build()
  // (see applications_provider.dart). Pull-to-refresh re-runs that load so this
  // screen — which can be opened straight from "My Jobs" — stays current.
  Future<void> _refresh() async {
    final me = ref.read(currentUserIdSyncProvider);
    if (me != null) {
      await ref
          .read(applicationsControllerProvider.notifier)
          .loadIncomingApplications(me);
    }
  }

  Future<void> _toggleVerified(bool next) async {
    final notifier = ref.read(applicationsControllerProvider.notifier);
    if (next) {
      notifier.setVerifiedOnlyFilter(true);
      return;
    }
    final already = await UnverifiedConsentDialog.hasAcknowledged(ref);
    if (already) {
      notifier.setVerifiedOnlyFilter(false);
      return;
    }
    if (!mounted) return;
    final ok = await UnverifiedConsentDialog.show(context, ref);
    if (ok) notifier.setVerifiedOnlyFilter(false);
  }

  void _openApplicant(JobApplication app) {
    context.push(
      '/jobs/${widget.args.jobId}/applicants/${app.id}',
      extra: ApplicantDetailArgs(application: app, jobTitle: widget.args.title),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final args = widget.args;
    final st = ref.watch(applicationsControllerProvider);

    // Applicants for THIS job, verified-first.
    final forJob =
        st.incomingApplications.where((a) => a.jobId == args.jobId).toList()
          ..sort((a, b) {
            final av = a.tradeIsVerified == true ? 0 : 1;
            final bv = b.tradeIsVerified == true ? 0 : 1;
            return av.compareTo(bv);
          });
    final hiddenUnverified = forJob
        .where((a) => a.tradeIsVerified != true)
        .length;
    final shown = st.verifiedOnlyFilter
        ? forJob.where((a) => a.tradeIsVerified == true).toList()
        : forJob;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, AppSpacing.sm.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  Expanded(
                    child: PageHeader(
                      eyebrow: 'APPLICANTS',
                      title: args.title,
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),

            // ── Body
            Expanded(
              child: st.isLoading && forJob.isEmpty
                  ? JSkeletonList(
                      enabled: true,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          AppSpacing.lg.h,
                          20.w,
                          AppSpacing.lg.h,
                        ),
                        itemCount: 4,
                        separatorBuilder: (_, _) => Gap(10.h),
                        itemBuilder: (_, _) => _ApplicantRow(
                          app: _placeholderApplicant,
                          onTap: () {},
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: c.action,
                      backgroundColor: c.card,
                      child: CustomScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        slivers: [
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              20.w,
                              AppSpacing.lg.h,
                              20.w,
                              AppSpacing.sm.h,
                            ),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _JobSummaryCard(args: args),
                                  Gap(AppSpacing.lg.h),
                                  Row(
                                    children: [
                                      Text(
                                        forJob.length == 1
                                            ? '1 APPLICANT'
                                            : '${forJob.length} APPLICANTS',
                                        style: tt.labelSmall!.copyWith(
                                          letterSpacing: 0.8,
                                          color: c.text2,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Verified only',
                                        style: tt.bodySmall!.copyWith(
                                          color: c.text3,
                                        ),
                                      ),
                                      Gap(8.w),
                                      JSwitch(
                                        value: st.verifiedOnlyFilter,
                                        onChanged: _toggleVerified,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (shown.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  20.w,
                                  AppSpacing.md.h,
                                  20.w,
                                  0,
                                ),
                                child:
                                    (hiddenUnverified > 0 &&
                                        st.verifiedOnlyFilter)
                                    ? _HiddenNotice(
                                        count: hiddenUnverified,
                                        onShowAll: () => _toggleVerified(false),
                                      )
                                    : const _EmptyApplicants(),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                AppSpacing.md.h,
                                20.w,
                                AppSpacing.xl.h +
                                    MediaQuery.of(context).padding.bottom,
                              ),
                              sliver: SliverList.builder(
                                itemCount: shown.length,
                                itemBuilder: (ctx, i) => Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: _ApplicantRow(
                                    app: shown[i],
                                    onTap: () => _openApplicant(shown[i]),
                                  ),
                                ),
                              ),
                            ),
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
