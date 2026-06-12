import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/app/constants/app_strings.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../messaging/presentation/pages/message_thread_page.dart';
import '../../../messaging/presentation/providers/messaging_provider.dart';
import '../../../reviews/presentation/widgets/review_cta.dart';
import '../../../verification/presentation/widgets/builder_verified_badge.dart';
import '../../../verification/presentation/widgets/unverified_consent_dialog.dart';
import '../../domain/entities/job_application.dart';
import '../providers/applications_provider.dart';
import 'application_tabs.dart';

part 'applications_page_card.dart';
part 'applications_page_widgets.dart';

class ApplicationsPage extends ConsumerStatefulWidget {
  const ApplicationsPage({super.key});

  @override
  ConsumerState<ApplicationsPage> createState() => _ApplicationsPageState();
}

class _ApplicationsPageState extends ConsumerState<ApplicationsPage> {
  AppTab _tab = AppTab.all;

  // Pull-to-refresh: re-run the role-appropriate load. The initial load is
  // owned by the controller's build() (see applications_provider.dart).
  Future<void> _refresh() async {
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId == null) return;
    final notifier = ref.read(applicationsControllerProvider.notifier);
    final isBuilder = ref.read(authControllerProvider).role == UserRole.builder;
    if (isBuilder) {
      await notifier.loadIncomingApplications(userId);
    } else {
      await notifier.loadMyApplications(userId);
    }
  }

  // Builder taps "Message" on an applicant → open (or create) the shared
  // conversation, then navigate to the thread. The tradie sees it in their
  // inbox and can reply.
  Future<void> _openConversation(JobApplication app) async {
    final convId = await ref
        .read(messagingControllerProvider.notifier)
        .getOrCreateConversation(
          builderId: app.builderId,
          tradeId: app.tradeId,
          jobId: app.jobId,
        );
    if (convId == null || !mounted) return;
    context.push(
      '/messages/$convId',
      extra: ConversationArgs(
        conversationId: convId,
        otherName: app.tradeFullName ?? 'Tradesperson',
        jobTitle: app.jobTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final tabs = ApplicationTabs.forRole(isBuilder: isBuilder);

    final rawList = isBuilder
        ? appsState.filteredIncoming
        : appsState.myApplications;
    final filtered = ApplicationTabs.filter(rawList, _tab);

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
                      itemBuilder: (ctx, i) {
                        final tab = tabs[i];
                        final n = ApplicationTabs.count(rawList, tab);
                        return GvChip(
                          label: n > 0 ? '${tab.label} · $n' : tab.label,
                          active: _tab == tab,
                          onTap: () => setState(() => _tab = tab),
                        );
                      },
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
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      color: c.action,
                      backgroundColor: c.card,
                      child: JStaggeredList(
                        animationKey: ValueKey(_tab),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          20.w,
                          AppSpacing.md.h,
                          20.w,
                          AppSpacing.xl.h +
                              MediaQuery.of(context).padding.bottom,
                        ),
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => Gap(10.h),
                        itemBuilder: (ctx, i) => _AppCard(
                          app: filtered[i],
                          isBuilder: isBuilder,
                          onUpdateStatus: isBuilder
                              ? (status) => ref
                                    .read(
                                      applicationsControllerProvider.notifier,
                                    )
                                    .updateStatus(filtered[i].id, status)
                              : null,
                          onWithdraw: !isBuilder
                              ? () => ref
                                    .read(
                                      applicationsControllerProvider.notifier,
                                    )
                                    .withdraw(filtered[i].id)
                              : null,
                          onMessage: isBuilder
                              ? () => _openConversation(filtered[i])
                              : null,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
