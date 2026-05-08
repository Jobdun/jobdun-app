import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/job_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  String? _activeFilter;

  static const _filters = [
    'All',
    'Electrician',
    'Plumber',
    'Carpenter',
    'Concreter',
    'Painter',
  ];

  static const _jobs = [
    _JobModel(
      id: '1',
      title: 'Install 3-phase switchboard at commercial site',
      description:
          'Install a 3-phase switchboard at our commercial fit-out in Surry Hills. Conduit run, panel installation, and termination. Must hold current NSW electrical licence.',
      company: 'Pinnacle Construct',
      suburb: 'Surry Hills, NSW',
      rate: r'$85/hr',
      startDate: 'Tomorrow 7am',
      distanceKm: 2.4,
      trade: 'Electrician',
      isUrgent: true,
      postedAgo: '2h ago',
    ),
    _JobModel(
      id: '2',
      title: 'Frame internal walls for home renovation',
      description:
          'Steel stud framing approximately 120 LM for a full renovation in Newtown. Drawings available on site. Supply your own tools.',
      company: 'BuildRight Pty Ltd',
      suburb: 'Newtown, NSW',
      rate: r'$45/hr',
      startDate: '12 May',
      distanceKm: 4.8,
      trade: 'Carpenter',
      isUrgent: false,
      postedAgo: '5h ago',
    ),
    _JobModel(
      id: '3',
      title: 'Concrete footings for deck extension',
      description:
          '8 × 300mm dia pad footings, 600mm deep. Reinforcement supplied by contractor. All approvals in place.',
      company: 'Coast & Country Builds',
      suburb: 'Cronulla, NSW',
      rate: r'$75/hr',
      startDate: '14 May',
      distanceKm: 9.1,
      trade: 'Concreter',
      isUrgent: false,
      postedAgo: '1d ago',
    ),
    _JobModel(
      id: '4',
      title: 'Rough-in plumbing for new bathroom',
      description:
          'Rough-in plumbing for a new ensuite bathroom in Mosman. Shower, vanity, toilet, and bath connections. Hot and cold supply, sewer connections to existing stack.',
      company: 'Prestige Renos',
      suburb: 'Mosman, NSW',
      rate: r'$1,800 fixed',
      startDate: '15 May',
      distanceKm: 6.3,
      trade: 'Plumber',
      isUrgent: false,
      postedAgo: '2d ago',
    ),
    _JobModel(
      id: '5',
      title: 'Roof repair — replace tiles and re-bed ridge',
      description:
          'Approx 20 broken tiles to replace following storm damage. Ridge re-bedding on east face. Scaffold supplied. Must be available immediately.',
      company: 'Harbour Homes',
      suburb: 'Balmain, NSW',
      rate: r'$55/hr',
      startDate: 'Today',
      distanceKm: 3.7,
      trade: 'Painter',
      isUrgent: true,
      postedAgo: '3h ago',
    ),
    _JobModel(
      id: '6',
      title: 'Interior paint — 4-bedroom home repaint',
      description:
          'Full interior repaint of a 4-bedroom home before sale. Walls, ceilings, trims. Paint supplied. 2 coats Dulux Wash&Wear throughout.',
      company: 'Domain Developments',
      suburb: 'Randwick, NSW',
      rate: r'$3,500 fixed',
      startDate: '18 May',
      distanceKm: 7.2,
      trade: 'Painter',
      isUrgent: false,
      postedAgo: '4d ago',
    ),
  ];

  List<_JobModel> get _filtered {
    if (_activeFilter == null || _activeFilter == 'All') return _jobs;
    return _jobs.where((j) => j.trade == _activeFilter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isBuilder = ref.watch(authControllerProvider).role == UserRole.builder;
    final results = _filtered;

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
                  Row(
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
                                color: c.text3,
                              ),
                            ),
                            Gap(4.h),
                            ShaderMask(
                              shaderCallback: (bounds) => const LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color(0xFFFFB300),
                                  Color(0xFFF97316),
                                  Color(0xFFE64A19),
                                ],
                              ).createShader(bounds),
                              child: Text(
                                isBuilder ? 'Your listings' : 'Open near you',
                                style: GoogleFonts.barlowCondensed(
                                  fontSize: 28.sp,
                                  fontWeight: FontWeight.w800,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.02 * 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isBuilder)
                        GestureDetector(
                          onTap: () {},
                          child: Container(
                            height: 36.h,
                            padding: EdgeInsets.symmetric(horizontal: 14.w),
                            decoration: BoxDecoration(
                              color: c.action,
                              borderRadius: BorderRadius.circular(AppRadius.btn.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Iconsax.add, size: 16.r, color: Colors.white),
                                Gap(6.w),
                                Text(
                                  'POST JOB',
                                  style: GoogleFonts.barlow(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  Gap(12.h),
                  // ── Search bar — 40px height per spec
                  Container(
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(AppRadius.input.r),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        Gap(14.w),
                        Icon(Iconsax.search_normal, size: 16.r, color: c.text3),
                        Gap(8.w),
                        Text(
                          'Search trades, skills, suburbs…',
                          style: GoogleFonts.barlow(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w400,
                            color: c.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap(12.h),
                  // ── Filter chips
                  SizedBox(
                    height: 30.h,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (ctx, idx) => Gap(8.w),
                      itemBuilder: (context, i) {
                        final f = _filters[i];
                        final isActive =
                            f == _activeFilter || (i == 0 && _activeFilter == null);
                        return GvChip(
                          label: f,
                          active: isActive,
                          onTap: () =>
                              setState(() => _activeFilter = f == 'All' ? null : f),
                        );
                      },
                    ),
                  ),
                  Gap(12.h),
                  Divider(height: 1, color: c.border),
                ],
              ),
            ),
            // ── Results count
            Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 4.h),
              child: Text(
                '${results.length} ${results.length == 1 ? 'job' : 'jobs'} found',
                style: GoogleFonts.barlow(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w400,
                  color: c.text3,
                ),
              ),
            ),
            // ── Job list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                itemCount: results.length,
                separatorBuilder: (ctx, idx) => Gap(9.h),
                itemBuilder: (context, i) {
                  final j = results[i];
                  return JobCard(
                    title: j.title,
                    description: j.description,
                    rate: j.rate,
                    startDate: j.startDate,
                    distanceKm: j.distanceKm,
                    isUrgent: j.isUrgent,
                    onTap: () {},
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JobModel {
  const _JobModel({
    required this.id,
    required this.title,
    required this.description,
    required this.company,
    required this.suburb,
    required this.rate,
    required this.startDate,
    required this.distanceKm,
    required this.trade,
    required this.isUrgent,
    required this.postedAgo,
  });

  final String id;
  final String title;
  final String description;
  final String company;
  final String suburb;
  final String rate;
  final String startDate;
  final double distanceKm;
  final String trade;
  final bool isUrgent;
  final String postedAgo;
}
