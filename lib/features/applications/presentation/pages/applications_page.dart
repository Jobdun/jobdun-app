import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/app/constants/app_strings.dart';
import 'package:jobdun/app/theme/app_typography.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../../core/design/widgets/animated_empty_glyph.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/design/widgets/jobdun_logo.dart';
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

  // 2026-08-18 audit (#9): in-flight guard so a double-tap on MESSAGE can't
  // fire the get_or_create_conversation RPC twice and push the thread twice.
  bool _openingConversation = false;

  // 2026-08-18 audit (#3): reentrancy guard for status mutations — a second
  // tap while a shortlist/reject/withdraw is in flight is ignored.
  bool _mutating = false;

  // 2026-08-18 audit (#1): remembers which error message the user dismissed
  // from the inline banner, so it doesn't re-appear on every rebuild.
  String? _dismissedError;

  // Pull-to-refresh: re-run the role-appropriate load. The initial load is
  // owned by the controller's build() (see applications_provider.dart).
  Future<void> _refresh() async {
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId == null) return;
    _dismissedError = null; // a new attempt re-arms the error banner
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
    if (_openingConversation) return;
    _openingConversation = true;
    try {
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
    } finally {
      _openingConversation = false;
    }
  }

  // 2026-08-18 audit (#3): await the mutation and surface failures — these
  // were fire-and-forget, so a failed shortlist/reject looked like success.
  Future<void> _updateStatus(String applicationId, ApplicationStatus status) =>
      _runMutation(
        () => ref
            .read(applicationsControllerProvider.notifier)
            .updateStatus(applicationId, status),
      );

  Future<void> _withdraw(String applicationId) => _runMutation(
    () => ref
        .read(applicationsControllerProvider.notifier)
        .withdraw(applicationId),
  );

  Future<void> _runMutation(Future<bool> Function() action) async {
    if (_mutating) return;
    _mutating = true;
    try {
      final ok = await action();
      if (!ok && mounted) {
        final error = ref.read(applicationsControllerProvider).error;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error ?? "Couldn't complete that action. Please try again.",
            ),
          ),
        );
      }
    } finally {
      _mutating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
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
            // ── Header — Figma `JobDun-Screens` → Applicants (node 113:4090)
            // puts the mark on the 16dp margin and the screen name in Inter
            // Bold 24, on the page ground: no card, no rule underneath.
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md.w,
                AppSpacing.sm.h,
                AppSpacing.md.w,
                AppSpacing.sm.h,
              ),
              child: Row(
                children: [
                  JobdunLogo(variant: LogoVariant.mark, height: 32.h),
                  Gap(AppSpacing.sm.w),
                  Expanded(
                    child: Text(
                      isBuilder ? 'Applicants' : 'Track status',
                      style: tt.titleMedium!.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        color: c.text1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBuilder) ...[
                    Gap(AppSpacing.md.h),
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
                  // Figma stacks the body sections on a 24dp rhythm.
                  Gap(AppSpacing.lg.h),
                  // ── Tab chips
                  SizedBox(
                    height: 44.h,
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
                ],
              ),
            ),
            // ── List
            // 2026-08-18 audit (#1): a failed load now renders an error state
            // with RETRY (empty list) or a dismissible banner (stale data),
            // instead of masquerading as "no applications yet".
            // 2026-08-18 audit (#2): RefreshIndicator wraps EVERY branch so a
            // failed/empty load is always recoverable by pull — the tab lives
            // in an IndexedStack shell, so initState never re-runs.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (appsState.error != null &&
                      rawList.isNotEmpty &&
                      appsState.error != _dismissedError)
                    _ErrorBanner(
                      message: appsState.error!,
                      onDismiss: () =>
                          setState(() => _dismissedError = appsState.error),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _refresh,
                      color: c.action,
                      backgroundColor: c.card,
                      child: appsState.isLoading && filtered.isEmpty
                          ? JSkeletonList(
                              enabled: true,
                              child: ListView.separated(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  AppSpacing.md.w,
                                  AppSpacing.md.h,
                                  AppSpacing.md.w,
                                  AppSpacing.xl.h,
                                ),
                                itemCount: 4,
                                separatorBuilder: (_, _) =>
                                    Gap(AppSpacing.md.h),
                                itemBuilder: (_, _) => _AppCard(
                                  app: _placeholderApp,
                                  isBuilder: isBuilder,
                                ),
                              ),
                            )
                          : appsState.error != null && rawList.isEmpty
                          ? _ScrollableFill(
                              child: _ErrorState(
                                message: appsState.error!,
                                onRetry: () => _refresh(),
                              ),
                            )
                          : filtered.isEmpty
                          ? _ScrollableFill(
                              child: _EmptyTab(tab: _tab, isBuilder: isBuilder),
                            )
                          : JStaggeredList(
                              animationKey: ValueKey(_tab),
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.fromLTRB(
                                AppSpacing.md.w,
                                AppSpacing.md.h,
                                AppSpacing.md.w,
                                AppSpacing.xl.h +
                                    MediaQuery.of(context).padding.bottom,
                              ),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => Gap(AppSpacing.md.h),
                              itemBuilder: (ctx, i) => _AppCard(
                                app: filtered[i],
                                isBuilder: isBuilder,
                                onUpdateStatus: isBuilder
                                    ? (status) =>
                                          _updateStatus(filtered[i].id, status)
                                    : null,
                                onWithdraw: !isBuilder
                                    ? () => _withdraw(filtered[i].id)
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
          ],
        ),
      ),
    );
  }
}
