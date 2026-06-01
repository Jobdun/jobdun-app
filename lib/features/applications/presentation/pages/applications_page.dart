import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../verification/presentation/widgets/builder_verified_badge.dart';
import '../../../verification/presentation/widgets/unverified_consent_dialog.dart';
import '../../domain/entities/job_application.dart';
import '../providers/applications_provider.dart';

part 'applications_page_card.dart';
part 'applications_page_widgets.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  String _tab = 'All';

  static const _tradeTabs = ['All', 'Pending', 'Shortlisted', 'Hired'];
  static const _builderTabs = [
    'All',
    'Pending',
    'Shortlisted',
    'Hired',
    'Rejected',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = ref.read(currentUserIdSyncProvider);
      if (userId == null) return;
      final role = ref.read(authControllerProvider).role;
      if (role == UserRole.builder) {
        ref
            .read(applicationsControllerProvider.notifier)
            .loadIncomingApplications(userId);
      } else {
        ref
            .read(applicationsControllerProvider.notifier)
            .loadMyApplications(userId);
      }
    });
  }

  List<JobApplication> _filtered(List<JobApplication> apps) {
    if (_tab == 'All') return apps;
    return apps.where((a) {
      return switch (_tab) {
        'Pending' => a.status == ApplicationStatus.pending,
        'Shortlisted' => a.status == ApplicationStatus.shortlisted,
        'Hired' => a.status == ApplicationStatus.hired,
        'Rejected' => a.status == ApplicationStatus.rejected,
        _ => true,
      };
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final tabs = isBuilder ? _builderTabs : _tradeTabs;

    final rawList = isBuilder
        ? appsState.filteredIncoming
        : appsState.myApplications;
    final filtered = _filtered(rawList);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PageHeader(title: isBuilder ? 'Applicants' : 'Track status'),
                  if (isBuilder) ...[
                    Gap(8.h),
                    _VerifiedOnlyToggle(
                      value: appsState.verifiedOnlyFilter,
                      onChanged: (next) async {
                        if (next) {
                          ref
                              .read(applicationsControllerProvider.notifier)
                              .setVerifiedOnlyFilter(true);
                          return;
                        }
                        final already =
                            await UnverifiedConsentDialog.hasAcknowledged(ref);
                        if (already) {
                          ref
                              .read(applicationsControllerProvider.notifier)
                              .setVerifiedOnlyFilter(false);
                          return;
                        }
                        if (!context.mounted) return;
                        final ok = await UnverifiedConsentDialog.show(
                          context,
                          ref,
                        );
                        if (ok) {
                          ref
                              .read(applicationsControllerProvider.notifier)
                              .setVerifiedOnlyFilter(false);
                        }
                      },
                    ),
                  ],
                  Gap(12.h),
                  // ── Tab chips
                  SizedBox(
                    height: 30.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: tabs.length,
                      separatorBuilder: (_, _) => Gap(AppSpacing.sm.w),
                      itemBuilder: (ctx, i) => GvChip(
                        label: tabs[i],
                        active: _tab == tabs[i],
                        onTap: () => setState(() => _tab = tabs[i]),
                      ),
                    ),
                  ),
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                ],
              ),
            ),
            // ── List
            Expanded(
              child: appsState.isLoading && filtered.isEmpty
                  ? JSkeletonList(
                      enabled: true,
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          AppSpacing.md.h,
                          20.w,
                          AppSpacing.lg.h,
                        ),
                        itemCount: 4,
                        separatorBuilder: (_, _) => Gap(10.h),
                        itemBuilder: (_, _) => _AppCard(
                          app: _placeholderApp,
                          isBuilder: isBuilder,
                        ),
                      ),
                    )
                  : filtered.isEmpty
                  ? _EmptyTab(tab: _tab, isBuilder: isBuilder)
                  : JStaggeredList(
                      animationKey: ValueKey(_tab),
                      padding: EdgeInsets.fromLTRB(
                        20.w,
                        AppSpacing.md.h,
                        20.w,
                        AppSpacing.lg.h,
                      ),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => Gap(10.h),
                      itemBuilder: (ctx, i) => _AppCard(
                        app: filtered[i],
                        isBuilder: isBuilder,
                        onUpdateStatus: isBuilder
                            ? (status) => ref
                                  .read(applicationsControllerProvider.notifier)
                                  .updateStatus(filtered[i].id, status)
                            : null,
                        onWithdraw: !isBuilder
                            ? () => ref
                                  .read(applicationsControllerProvider.notifier)
                                  .withdraw(filtered[i].id)
                            : null,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
