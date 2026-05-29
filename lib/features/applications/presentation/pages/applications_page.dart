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
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../verification/presentation/widgets/unverified_consent_dialog.dart';
import '../../domain/entities/job_application.dart';
import '../providers/applications_provider.dart';

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
    final useReal = rawList.isNotEmpty;
    final filtered = useReal
        ? _filtered(rawList)
        : _filtered(_mockApps(isBuilder));

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

// ── Application Card ───────────────────────────────────────────────────────────

class _AppCard extends StatelessWidget {
  const _AppCard({
    required this.app,
    required this.isBuilder,
    this.onUpdateStatus,
    this.onWithdraw,
  });

  final JobApplication app;
  final bool isBuilder;
  final void Function(ApplicationStatus)? onUpdateStatus;
  final VoidCallback? onWithdraw;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final status = app.status;
    final statusColor = _statusColor(status, c);
    final statusLabel = status.label.toUpperCase();

    final card = _buildCard(context, c, tt, status, statusColor, statusLabel);

    // Swipe affordances on pending rows only. Builders get reject/shortlist;
    // tradies get withdraw. The inline buttons remain — slidable is additive
    // for power users, not a replacement.
    if (status != ApplicationStatus.pending) return card;

    if (isBuilder) {
      return Slidable(
        key: ValueKey('app-${app.id}'),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.28,
          children: [
            _slideAction(
              context: context,
              label: 'REJECT',
              icon: AppIcons.closeCircle,
              backgroundColor: c.urgent,
              onPressed: () => onUpdateStatus?.call(ApplicationStatus.rejected),
            ),
          ],
        ),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.32,
          children: [
            _slideAction(
              context: context,
              label: 'SHORTLIST',
              icon: AppIcons.successCircle,
              backgroundColor: c.available,
              onPressed: () =>
                  onUpdateStatus?.call(ApplicationStatus.shortlisted),
            ),
          ],
        ),
        child: card,
      );
    }

    return Slidable(
      key: ValueKey('app-${app.id}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.32,
        children: [
          _slideAction(
            context: context,
            label: 'WITHDRAW',
            icon: AppIcons.closeBox,
            backgroundColor: c.surfaceRaised,
            foregroundColor: c.text1,
            onPressed: () => onWithdraw?.call(),
          ),
        ],
      ),
      child: card,
    );
  }

  Widget _buildCard(
    BuildContext context,
    JColors c,
    TextTheme tt,
    ApplicationStatus status,
    Color statusColor,
    String statusLabel,
  ) {
    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(
          color: status == ApplicationStatus.shortlisted ? c.action : c.border,
          width: status == ApplicationStatus.shortlisted ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Status bar
          Container(
            height: 3.h,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppRadius.card.r),
                topRight: Radius.circular(AppRadius.card.r),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md.r),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status chip + date
                Row(
                  children: [
                    Flexible(
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        ),
                        child: Text(
                          statusLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.5,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Gap(8.w),
                    Text(
                      _relDate(app.createdAt),
                      style: tt.bodySmall!.copyWith(color: c.text3),
                    ),
                  ],
                ),
                Gap(10.h),
                // ── Job title
                Text(
                  app.jobTitle ?? '—',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.headlineSmall!.copyWith(
                    fontSize: 18.sp,
                    color: c.text1,
                    height: 1.1,
                  ),
                ),
                Gap(4.h),
                // ── Company / trade name
                Row(
                  children: [
                    Icon(
                      isBuilder ? AppIcons.licence : AppIcons.building,
                      size: 13.r,
                      color: c.text3,
                    ),
                    Gap(6.w),
                    Flexible(
                      child: Text(
                        isBuilder
                            ? (app.tradeFullName ?? '—')
                            : (app.builderCompanyName ?? '—'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium!.copyWith(
                          fontWeight: FontWeight.w600,
                          color: c.text2,
                        ),
                      ),
                    ),
                    if (isBuilder && app.tradeIsVerified == true) ...[
                      Gap(6.w),
                      Icon(AppIcons.verified, size: 13.r, color: c.verified),
                    ],
                  ],
                ),
                Gap(4.h),
                // ── Location
                Row(
                  children: [
                    Icon(AppIcons.location, size: 13.r, color: c.text3),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        [
                          app.jobSuburb,
                          app.jobState,
                        ].whereType<String>().join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium!.copyWith(color: c.text3),
                      ),
                    ),
                    if (app.proposedRate != null) ...[
                      Gap(8.w),
                      Text(
                        '\$${app.proposedRate!.toStringAsFixed(0)}${app.proposedRateType != null ? '/${app.proposedRateType}' : ''}',
                        style: tt.headlineSmall!.copyWith(
                          fontSize: 15.sp,
                          color: c.action,
                        ),
                      ),
                    ],
                  ],
                ),
                // ── Builder actions (shortlist → hire / reject)
                if (isBuilder && status == ApplicationStatus.pending) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  Row(
                    children: [
                      Expanded(
                        child: JButton(
                          label: 'REJECT',
                          variant: JButtonVariant.secondary,
                          size: JButtonSize.compact,
                          onPressed: () =>
                              onUpdateStatus?.call(ApplicationStatus.rejected),
                        ),
                      ),
                      Gap(AppSpacing.sm.w),
                      Expanded(
                        child: JButton(
                          label: 'SHORTLIST',
                          size: JButtonSize.compact,
                          onPressed: () => onUpdateStatus?.call(
                            ApplicationStatus.shortlisted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (isBuilder && status == ApplicationStatus.shortlisted) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  GestureDetector(
                    onTap: () => onUpdateStatus?.call(ApplicationStatus.hired),
                    child: Container(
                      width: double.infinity,
                      height: 34.h,
                      decoration: BoxDecoration(
                        color: c.verified,
                        borderRadius: BorderRadius.circular(AppRadius.btn.r),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'HIRE THIS TRADIE',
                        style: tt.labelMedium!.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Colors.white, // intentional: white-on-action
                        ),
                      ),
                    ),
                  ),
                ],
                // ── Trade: withdraw pending
                if (!isBuilder && status == ApplicationStatus.pending) ...[
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                  Gap(10.h),
                  GestureDetector(
                    onTap: onWithdraw,
                    child: Text(
                      'Withdraw application',
                      style: tt.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w500,
                        color: c.text3,
                        decoration: TextDecoration.underline,
                        decorationColor: c.text3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  SlidableAction _slideAction({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color backgroundColor,
    Color? foregroundColor,
    required VoidCallback onPressed,
  }) {
    final c = context.c;
    return SlidableAction(
      onPressed: (_) {
        HapticFeedback.lightImpact();
        onPressed();
      },
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor ?? c.onAction,
      icon: icon,
      label: label,
      autoClose: true,
    );
  }

  static Color _statusColor(ApplicationStatus s, JColors c) => switch (s) {
    ApplicationStatus.pending => c.action,
    ApplicationStatus.shortlisted => c.available,
    ApplicationStatus.hired => c.verified,
    ApplicationStatus.rejected => c.urgent,
    ApplicationStatus.withdrawn => c.text3,
    ApplicationStatus.declinedByTrade => c.text3,
  };

  static String _relDate(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ── Empty tab state ────────────────────────────────────────────────────────────

class _EmptyTab extends StatelessWidget {
  const _EmptyTab({required this.tab, required this.isBuilder});

  final String tab;
  final bool isBuilder;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final message = tab == 'All'
        ? isBuilder
              ? 'No applicants yet.\nPost a job to start receiving applications.'
              : 'No applications yet.\nBrowse open jobs to get started.'
        : 'No $tab applications.';

    // CTA only on the "All" tab — secondary tab empties shouldn't push the
    // user to take an unrelated action.
    final ctaLabel = tab == 'All'
        ? (isBuilder ? 'POST A JOB' : 'BROWSE JOBS')
        : null;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.document, size: 48.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              message,
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
            if (ctaLabel != null) ...[
              Gap(AppSpacing.lg.h),
              SizedBox(
                width: 200.w,
                child: JButton(
                  label: ctaLabel,
                  onPressed: () => context.go(isBuilder ? '/jobs' : '/jobs'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// Loading-state placeholder. Real-shaped JobApplication so Skeletonizer can
// mask the card layout into shimmer blocks during initial load.
final _placeholderApp = JobApplication(
  id: 'placeholder',
  jobId: 'placeholder',
  tradeId: 'placeholder',
  builderId: 'placeholder',
  status: ApplicationStatus.pending,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  jobTitle: 'Loading job title placeholder',
  jobSuburb: 'Suburb',
  jobState: 'NSW',
  builderCompanyName: 'Loading company placeholder',
  tradeFullName: 'Loading trade name placeholder',
  tradePrimaryTrade: 'Trade',
  tradeIsVerified: false,
  proposedRate: 0,
  proposedRateType: 'hr',
);

// ── Sample mock data (shown when provider returns empty) ───────────────────────

List<JobApplication> _mockApps(bool isBuilder) => [
  JobApplication(
    id: 'mock-1',
    jobId: 'j1',
    tradeId: 't1',
    builderId: 'b1',
    status: ApplicationStatus.pending,
    createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    jobTitle: 'Install 3-phase switchboard',
    jobSuburb: 'Surry Hills',
    jobState: 'NSW',
    builderCompanyName: 'Pinnacle Construct',
    tradeFullName: 'Marcus Webb',
    tradePrimaryTrade: 'Electrician',
    tradeIsVerified: true,
    proposedRate: 85,
    proposedRateType: 'hr',
  ),
  JobApplication(
    id: 'mock-2',
    jobId: 'j2',
    tradeId: 't2',
    builderId: 'b1',
    status: ApplicationStatus.shortlisted,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    jobTitle: 'Frame internal walls — Newtown renovation',
    jobSuburb: 'Newtown',
    jobState: 'NSW',
    builderCompanyName: 'BuildRight Pty Ltd',
    tradeFullName: "Sarah O'Brien",
    tradePrimaryTrade: 'Carpenter',
    tradeIsVerified: true,
    proposedRate: 45,
    proposedRateType: 'hr',
  ),
  JobApplication(
    id: 'mock-3',
    jobId: 'j3',
    tradeId: 't3',
    builderId: 'b1',
    status: ApplicationStatus.hired,
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    jobTitle: 'Concrete footings for deck extension',
    jobSuburb: 'Cronulla',
    jobState: 'NSW',
    builderCompanyName: 'Coast & Country Builds',
    tradeFullName: 'Jake Kowalski',
    tradePrimaryTrade: 'Concreter',
    tradeIsVerified: false,
    proposedRate: 75,
    proposedRateType: 'hr',
  ),
];

class _VerifiedOnlyToggle extends StatelessWidget {
  const _VerifiedOnlyToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        Expanded(
          child: Text(
            'Verified workers only',
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: c.text2,
            ),
          ),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: c.action),
      ],
    );
  }
}
