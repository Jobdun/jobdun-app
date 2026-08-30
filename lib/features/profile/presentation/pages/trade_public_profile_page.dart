import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_stats_row.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../verification/domain/entities/verification.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../../verification/presentation/widgets/verification_receipts.dart';
import '../../domain/entities/trade_profile.dart';
import '../providers/profile_provider.dart';
import '../widgets/portfolio_strip.dart';
import '../widgets/profile_about_section.dart';
import '../widgets/profile_rating_block.dart';
import '../widgets/profile_reviews_preview.dart';

/// Fetches a tradie's profile for the public (builder-facing) view.
/// autoDispose so each open re-fetches. Returns null on error/soft-delete so
/// the page shows an empty state instead of crashing a builder mid-decision.
final tradePublicProfileProvider = FutureProvider.autoDispose
    .family<TradeProfile?, String>((ref, tradeId) async {
      final res = await ref
          .read(profileRepositoryProvider)
          .getTradePublicProfile(tradeId);
      return res.fold((_) => null, (p) => p);
    });

/// Public tradie profile — the mirror of [BuilderPublicProfilePage], and what
/// a builder sees BEFORE messaging or hiring: is this a real, licensed tradie
/// with a track record? Trade + licence ✓ + portfolio + reviews.
///
/// Reached from a discovery tile at `/trades/:id`, and from the tradie's own
/// "Preview public profile" link — the same see-what-they-see affordance the
/// builder profile has had since S12.
///
/// Reads the `trade_profiles_public` view, so anything the tradie chose to
/// keep private (their rate, when `hourly_rate_visible` is off) simply is not
/// in the payload. The page renders what it is given and claims nothing else.
class TradePublicProfilePage extends ConsumerWidget {
  const TradePublicProfilePage({super.key, required this.tradeId});

  final String tradeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(tradePublicProfileProvider(tradeId));
    final isVerified = ref
        .watch(verificationsForUserProvider(tradeId))
        .maybeWhen(
          data: (rows) => rows.any(
            (v) => v.kind == VerificationKind.licence && v.isVerified,
          ),
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
                    tooltip: 'Back',
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  const Expanded(
                    child: PageHeader(
                      title: 'Tradie',
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
                    : _TradePublicBody(
                        profile: p,
                        tradeId: tradeId,
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

class _TradePublicBody extends StatelessWidget {
  const _TradePublicBody({
    required this.profile,
    required this.tradeId,
    required this.isVerified,
  });

  final TradeProfile profile;
  final String tradeId;
  final bool isVerified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final p = profile;

    final rating = p.averageRating?.toStringAsFixed(1) ?? '—';
    final yrsExp = p.yearsExperience != null ? '${p.yearsExperience}+' : '—';
    final crew = p.crewSize <= 1 ? 'Solo' : '${p.crewSize}';
    final trade = p.displayTrade.trim();

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarBlock(
                initials: StringUtils.initials(p.fullName),
                size: 64,
                circle: true,
              ),
              Gap(AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName,
                      style: tt.titleLarge!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                    if (trade.isNotEmpty) ...[
                      Gap(4.h),
                      Text(
                        trade,
                        style: tt.bodyMedium!.copyWith(color: c.text2),
                      ),
                    ],
                    if (isVerified) ...[
                      Gap(AppSpacing.sm.h),
                      const JChip(label: 'LICENCE VERIFIED'),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Gap(AppSpacing.lg.h),
          // The public view has no jobs_completed / hire_count column, so the
          // third figure is crew size rather than a jobs count — inventing one
          // from an absent column is exactly the trap the owner-side profile
          // just got fixed for.
          JStatsRow(
            stats: [
              JStat(value: rating, label: 'Rating'),
              JStat(value: yrsExp, label: 'Yrs Exp', valueColor: c.warning),
              JStat(value: crew, label: 'Crew', valueColor: c.verified),
            ],
          ),
          Gap(AppSpacing.md.h),
          // No addPrompt: this is the how-others-see-you view, so a blank bio
          // hides the section rather than begging a stranger to fill it in.
          ProfileAboutSection(about: p.about, label: 'About'),
          Gap(AppSpacing.md.h),
          // Explicit urls, not the signed-in owner's strip — this is someone
          // else's work. Passing `urls` makes it a read-only showcase.
          if (p.portfolioCount > 0) ...[
            PortfolioStrip(urls: p.portfolioUrls),
            Gap(AppSpacing.md.h),
          ],
          ProfileRatingBlock(average: p.averageRating, count: p.ratingCount),
          if (p.ratingCount > 0) Gap(AppSpacing.sm.h),
          ProfileReviewsPreview(
            userId: tradeId,
            emptyMessage: 'No reviews yet — be the first to hire them.',
          ),
          Gap(AppSpacing.md.h),
          VerificationReceipts(
            userId: tradeId,
            isOwner: false,
            showAbnRow: false,
            showLicenceRow: true,
            showWhiteCardRow: true,
            showInsuranceRow: true,
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
      padding: EdgeInsets.fromLTRB(16.w, 20.h, 16.w, 0),
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
            Icon(AppIcons.user, size: AppIconSize.feature.r, color: c.text3),
            Gap(12.h),
            Text(
              "Couldn't load this tradie",
              textAlign: TextAlign.center,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(4.h),
            Text(
              'Their profile may be unavailable. You can still reach them from '
              'their application.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium!.copyWith(color: c.text3, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
