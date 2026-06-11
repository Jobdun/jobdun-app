import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../verification/domain/entities/verification.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../../verification/presentation/widgets/verification_receipts.dart';
import '../../domain/entities/builder_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_about_section.dart';
import '../widgets/profile_rating_block.dart';
import '../widgets/profile_reviews_preview.dart';

/// Fetches a builder's profile for the public (tradie-facing) view. autoDispose
/// so each open re-fetches. Returns null on error/soft-delete so the page shows
/// an empty state instead of crashing a tradie mid-decision.
final builderPublicProfileProvider = FutureProvider.autoDispose
    .family<BuilderProfile?, String>((ref, builderId) async {
      final res = await ref
          .read(profileRepositoryProvider)
          .getBuilderPublicProfile(builderId);
      return res.fold((_) => null, (p) => p);
    });

/// Public builder profile (S13) — what a tradie sees BEFORE applying: is this a
/// real, paying business? Company + ABN ✓ + track record + reviews from other
/// tradies. Opened from a job's POSTED BY card at `/builders/:id`.
class BuilderPublicProfilePage extends ConsumerWidget {
  const BuilderPublicProfilePage({super.key, required this.builderId});

  final String builderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(builderPublicProfileProvider(builderId));
    final isVerified = ref
        .watch(verificationsForUserProvider(builderId))
        .maybeWhen(
          data: (rows) =>
              rows.any((v) => v.kind == VerificationKind.abn && v.isVerified),
          orElse: () => false,
        );

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
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
                  const Expanded(
                    child: PageHeader(
                      title: 'Builder',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: async.when(
                loading: () => const _PublicLoading(),
                error: (_, _) => const _PublicEmpty(),
                data: (p) => p == null
                    ? const _PublicEmpty()
                    : _BuilderPublicBody(
                        profile: p,
                        builderId: builderId,
                        isVerified: isVerified,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderPublicBody extends StatelessWidget {
  const _BuilderPublicBody({
    required this.profile,
    required this.builderId,
    required this.isVerified,
  });

  final BuilderProfile profile;
  final String builderId;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final p = profile;
    final since = p.yearsInBusiness != null ? '${p.yearsInBusiness}' : '—';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBlock(
                initials: StringUtils.initials(p.companyName),
                size: 64,
                circle: true,
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.companyName,
                      style: tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                    if (isVerified) ...[
                      Gap(AppSpacing.sm.h),
                      const JChip(label: 'ABN VERIFIED'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap(AppSpacing.lg.h),
          Row(
            children: [
              JStatBadge(
                value: '${p.totalJobsPosted}',
                label: 'Jobs posted',
                icon: AppIcons.briefcase,
                iconColor: c.action,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: '${p.hireCount}',
                label: 'Hires',
                icon: AppIcons.user,
                iconColor: c.verified,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: since,
                label: 'Years',
                icon: AppIcons.calendar,
                iconColor: c.star,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          ProfileAboutSection(about: p.about, label: 'ABOUT THE COMPANY'),
          Gap(AppSpacing.md.h),
          ProfileRatingBlock(average: p.averageRating, count: p.ratingCount),
          if (p.ratingCount > 0) Gap(AppSpacing.sm.h),
          ProfileReviewsPreview(
            userId: builderId,
            emptyMessage: 'No reviews yet — be the first to work with them.',
          ),
          Gap(AppSpacing.md.h),
          VerificationReceipts(
            userId: builderId,
            isOwner: false,
            showLicenceRow: false,
          ),
        ],
      ),
    );
  }
}

class _PublicLoading extends StatelessWidget {
  const _PublicLoading();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 0),
      child: JSkeletonList(enabled: true, child: const SizedBox.expand()),
    );
  }
}

class _PublicEmpty extends StatelessWidget {
  const _PublicEmpty();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.building,
              size: AppIconSize.feature.r,
              color: c.text3,
            ),
            Gap(12.h),
            Text(
              "Couldn't load this builder",
              textAlign: TextAlign.center,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(4.h),
            Text(
              'Their profile may be unavailable. You can still apply from the job.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium!.copyWith(color: c.text3, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
