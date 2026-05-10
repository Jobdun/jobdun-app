import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_gradients.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  static const _builderTabs = ['All', 'Pending', 'Shortlisted', 'Hired', 'Rejected'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final userId = SupabaseConfig.isInitialized
          ? SupabaseConfig.client.auth.currentUser?.id
          : null;
      if (userId == null) return;
      final role = ref.read(authControllerProvider).role;
      if (role == UserRole.builder) {
        ref.read(applicationsControllerProvider.notifier).loadIncomingApplications(userId);
      } else {
        ref.read(applicationsControllerProvider.notifier).loadMyApplications(userId);
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
    final tt = Theme.of(context).textTheme;
    final authState = ref.watch(authControllerProvider);
    final appsState = ref.watch(applicationsControllerProvider);
    final isBuilder = authState.role == UserRole.builder;
    final tabs = isBuilder ? _builderTabs : _tradeTabs;

    final rawList = isBuilder ? appsState.incomingApplications : appsState.myApplications;
    final useReal = rawList.isNotEmpty;
    final filtered = useReal ? _filtered(rawList) : _filtered(_mockApps(isBuilder));

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
                  Text(
                    isBuilder ? 'INCOMING' : 'MY APPLICATIONS',
                    style: tt.labelSmall!.copyWith(
                      letterSpacing: 0.12 * 11,
                      color: c.text3,
                    ),
                  ),
                  Gap(4.h),
                  ShaderMask(
                    shaderCallback: (bounds) =>
                        AppGradients.brandFlame.createShader(bounds),
                    child: Text(
                      isBuilder ? 'Applicants' : 'Track status',
                      style: tt.headlineSmall!.copyWith(
                        fontSize: 28.sp,
                        letterSpacing: 0.02 * 28,
                        color: Colors.white, // intentional: ShaderMask requires white for gradient
                      ),
                    ),
                  ),
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
            if (appsState.isLoading)
              LinearProgressIndicator(
                color: c.action,
                backgroundColor: c.surface,
                minHeight: 2,
              ),
            // ── List
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyTab(tab: _tab, isBuilder: isBuilder)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(20.w, AppSpacing.md.h, 20.w, AppSpacing.lg.h),
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
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.chip.r),
                      ),
                      child: Text(
                        statusLabel,
                        style: tt.labelSmall!.copyWith(
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const Spacer(),
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
                      isBuilder ? Iconsax.personalcard : Iconsax.building_3,
                      size: 13.r,
                      color: c.text3,
                    ),
                    Gap(6.w),
                    Text(
                      isBuilder
                          ? (app.tradeFullName ?? '—')
                          : (app.builderCompanyName ?? '—'),
                      style: tt.bodyMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                        color: c.text2,
                      ),
                    ),
                    if (isBuilder && app.tradeIsVerified == true) ...[
                      Gap(6.w),
                      Icon(Iconsax.verify, size: 13.r, color: c.verified),
                    ],
                  ],
                ),
                Gap(4.h),
                // ── Location
                Row(
                  children: [
                    Icon(Iconsax.location, size: 13.r, color: c.text3),
                    Gap(6.w),
                    Text(
                      [app.jobSuburb, app.jobState].whereType<String>().join(', '),
                      style: tt.labelMedium!.copyWith(color: c.text3),
                    ),
                    if (app.proposedRate != null) ...[
                      const Spacer(),
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
                        child: GestureDetector(
                          onTap: () => onUpdateStatus?.call(ApplicationStatus.rejected),
                          child: Container(
                            height: 34.h,
                            decoration: BoxDecoration(
                              color: c.surface,
                              borderRadius: BorderRadius.circular(AppRadius.btn.r),
                              border: Border.all(color: c.border),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'REJECT',
                              style: tt.labelMedium!.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: c.text2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Gap(AppSpacing.sm.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onUpdateStatus?.call(ApplicationStatus.shortlisted),
                          child: Container(
                            height: 34.h,
                            decoration: BoxDecoration(
                              color: c.action,
                              borderRadius: BorderRadius.circular(AppRadius.btn.r),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'SHORTLIST',
                              style: tt.labelMedium!.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: Colors.white, // intentional: white-on-action
                              ),
                            ),
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

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.document_text, size: 48.r, color: c.text3),
            Gap(AppSpacing.md.h),
            Text(
              message,
              style: tt.bodyLarge!.copyWith(color: c.text3, height: 1.5),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

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
