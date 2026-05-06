import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  String? _activeFilter;

  static const _filters = ['All', 'Electrician', 'Plumber', 'Carpenter', 'Concreter', 'Painter'];

  static const _sampleJobs = [
    _JobData(
      id: '1',
      title: 'Install 3-phase switchboard at commercial site',
      company: 'Pinnacle Construct',
      suburb: 'Surry Hills',
      state: 'NSW',
      rate: '\$85/hr',
      rateType: 'Hourly',
      trade: 'Electrician',
      isUrgent: true,
      status: 'Open',
      postedAgo: '2h ago',
      description:
          'Looking for a licensed electrician to install a 3-phase switchboard at our commercial fit-out in Surry Hills. Work includes conduit run, panel installation, and termination. Must hold current NSW electrical licence.',
      duration: '3 days',
    ),
    _JobData(
      id: '2',
      title: 'Frame internal walls for home renovation',
      company: 'BuildRight Pty Ltd',
      suburb: 'Newtown',
      state: 'NSW',
      rate: '\$45/hr',
      rateType: 'Hourly',
      trade: 'Carpenter',
      isUrgent: false,
      status: 'Open',
      postedAgo: '5h ago',
      description:
          'Internal wall framing for a full home renovation in Newtown. Steel stud framing approximately 120 LM. Drawings available on site. Must supply own tools.',
      duration: '5 days',
    ),
    _JobData(
      id: '3',
      title: 'Concrete footings for deck extension',
      company: 'Coast & Country Builds',
      suburb: 'Cronulla',
      state: 'NSW',
      rate: '\$75/hr',
      rateType: 'Hourly',
      trade: 'Concreter',
      isUrgent: false,
      status: 'Open',
      postedAgo: '1d ago',
      description:
          'Concrete footings for a rear deck extension. 8 x 300mm dia pad footings, 600mm deep. Reinforcement to be supplied by contractor.',
      duration: '1 day',
    ),
    _JobData(
      id: '4',
      title: 'Rough-in plumbing for new bathroom',
      company: 'Prestige Renos',
      suburb: 'Mosman',
      state: 'NSW',
      rate: '\$1,800',
      rateType: 'Fixed',
      trade: 'Plumber',
      isUrgent: false,
      status: 'Open',
      postedAgo: '2d ago',
      description:
          'Rough-in plumbing for a new ensuite bathroom. Shower, vanity, toilet, and bath connections. Hot and cold supply, sewer connections to existing stack.',
      duration: '2 days',
    ),
    _JobData(
      id: '5',
      title: 'Roof repair — replace broken tiles and re-bed ridge',
      company: 'Harbour Homes',
      suburb: 'Balmain',
      state: 'NSW',
      rate: '\$55/hr',
      rateType: 'Hourly',
      trade: 'Roof Plumber',
      isUrgent: true,
      status: 'Open',
      postedAgo: '3h ago',
      description:
          'Urgent roof repair following storm damage. Approx 20 broken/cracked tiles to replace. Ridge re-bedding on east face. Scaffold supplied.',
      duration: '1 day',
    ),
    _JobData(
      id: '6',
      title: 'Interior paint — 4-bedroom home repaint',
      company: 'Domain Developments',
      suburb: 'Randwick',
      state: 'NSW',
      rate: '\$3,500',
      rateType: 'Fixed',
      trade: 'Painter',
      isUrgent: false,
      status: 'Open',
      postedAgo: '4d ago',
      description:
          'Full interior repaint of 4-bedroom home before sale. Walls, ceilings, trims. Paint supplied. 2 coats Dulux Wash&Wear throughout.',
      duration: '4 days',
    ),
  ];

  List<_JobData> get _filteredJobs {
    if (_activeFilter == null || _activeFilter == 'All') return _sampleJobs;
    return _sampleJobs.where((j) => j.trade == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBuilder = authState.role == UserRole.builder;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              color: AppColors.card,
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isBuilder ? 'POSTED JOBS' : 'FIND WORK',
                          style: GoogleFonts.barlow(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.12 * 11,
                            color: AppColors.text3,
                          ),
                        ),
                        Gap(4.h),
                        Text(
                          isBuilder ? 'Your job listings' : 'Open near you',
                          style: GoogleFonts.barlowCondensed(
                            fontSize: 26.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.02 * 26,
                            color: AppColors.text1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isBuilder)
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                        decoration: BoxDecoration(
                          color: AppColors.action,
                          borderRadius: BorderRadius.circular(AppRadius.btn.r),
                        ),
                        child: Row(
                          children: [
                            Icon(Iconsax.add, size: 16.r, color: Colors.white),
                            Gap(6.w),
                            Text(
                              'Post job',
                              style: GoogleFonts.barlow(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Search bar
            Container(
              color: AppColors.card,
              padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
              child: Container(
                height: 44.h,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.input.r),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Gap(12.w),
                    Icon(Iconsax.search_normal, size: 18.r, color: AppColors.text3),
                    Gap(8.w),
                    Text(
                      'Search jobs, trades, locations...',
                      style: GoogleFonts.barlow(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Filter chips
            Container(
              color: AppColors.card,
              child: Column(
                children: [
                  Divider(height: 1, color: AppColors.border),
                  SizedBox(
                    height: 44.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                      itemCount: _filters.length,
                      separatorBuilder: (context, index) => Gap(8.w),
                      itemBuilder: (context, i) {
                        final filter = _filters[i];
                        final isActive = filter == _activeFilter || (i == 0 && _activeFilter == null);
                        return GestureDetector(
                          onTap: () => setState(() => _activeFilter = filter == 'All' ? null : filter),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: isActive ? AppColors.foundation : AppColors.surface,
                              borderRadius: BorderRadius.circular(AppRadius.chip.r),
                              border: Border.all(
                                color: isActive ? AppColors.foundation : AppColors.border,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                filter,
                                style: GoogleFonts.barlow(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isActive ? Colors.white : AppColors.text2,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Job count
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
              child: Text(
                '${_filteredJobs.length} jobs found',
                style: GoogleFonts.barlow(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: AppColors.text3,
                ),
              ),
            ),
            // Jobs list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 24.h),
                itemCount: _filteredJobs.length,
                separatorBuilder: (ctx, idx) => Gap(12.h),
                itemBuilder: (context, i) => _JobCard(job: _filteredJobs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data model ─────────────────────────────────────────────────────────────────

class _JobData {
  const _JobData({
    required this.id,
    required this.title,
    required this.company,
    required this.suburb,
    required this.state,
    required this.rate,
    required this.rateType,
    required this.trade,
    required this.isUrgent,
    required this.status,
    required this.postedAgo,
    required this.description,
    required this.duration,
  });

  final String id;
  final String title;
  final String company;
  final String suburb;
  final String state;
  final String rate;
  final String rateType;
  final String trade;
  final bool isUrgent;
  final String status;
  final String postedAgo;
  final String description;
  final String duration;
}

// ── Job Card ───────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  const _JobCard({required this.job});

  final _JobData job;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(
            color: job.isUrgent ? AppColors.urgent : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + urgent badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    job.title,
                    style: GoogleFonts.barlow(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text1,
                      height: 1.35,
                    ),
                  ),
                ),
                if (job.isUrgent) ...[
                  Gap(8.w),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppColors.urgentBg,
                      borderRadius: BorderRadius.circular(AppRadius.badge.r),
                    ),
                    child: Text(
                      'URGENT',
                      style: GoogleFonts.barlow(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.06 * 10,
                        color: AppColors.urgentTx,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            Gap(8.h),
            // Company + location
            Row(
              children: [
                Icon(Iconsax.building_3, size: 13.r, color: AppColors.text3),
                Gap(4.w),
                Text(
                  job.company,
                  style: GoogleFonts.barlow(fontSize: 12.sp, color: AppColors.text2),
                ),
                Gap(12.w),
                Icon(Iconsax.location, size: 13.r, color: AppColors.text3),
                Gap(4.w),
                Text(
                  '${job.suburb}, ${job.state}',
                  style: GoogleFonts.barlow(fontSize: 12.sp, color: AppColors.text2),
                ),
              ],
            ),
            Gap(10.h),
            // Footer row
            Row(
              children: [
                // Trade chip
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.badge.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    job.trade,
                    style: GoogleFonts.barlow(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text2,
                    ),
                  ),
                ),
                Gap(8.w),
                // Duration chip
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.badge.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Iconsax.clock, size: 11.r, color: AppColors.text3),
                      Gap(3.w),
                      Text(
                        job.duration,
                        style: GoogleFonts.barlow(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w400,
                          color: AppColors.text2,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Rate
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      job.rate,
                      style: GoogleFonts.barlowCondensed(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.action,
                      ),
                    ),
                    Text(
                      job.rateType,
                      style: GoogleFonts.barlow(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.text3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Gap(10.h),
            Divider(height: 1, color: AppColors.border),
            Gap(10.h),
            // Posted time + apply button
            Row(
              children: [
                Icon(Iconsax.clock, size: 12.r, color: AppColors.text3),
                Gap(4.w),
                Text(
                  'Posted ${job.postedAgo}',
                  style: GoogleFonts.barlow(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                    color: AppColors.text3,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: AppColors.action,
                      borderRadius: BorderRadius.circular(AppRadius.btn.r),
                    ),
                    child: Text(
                      'Apply',
                      style: GoogleFonts.barlow(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
