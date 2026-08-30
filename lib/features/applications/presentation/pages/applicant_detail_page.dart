import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/app/theme/app_typography.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/section_label.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../messaging/presentation/pages/message_thread_page.dart';
import '../../../messaging/presentation/providers/messaging_provider.dart';
import '../../../profile/domain/entities/trade_profile.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../profile/presentation/widgets/portfolio_strip.dart';
import '../../../profile/presentation/widgets/profile_rating_block.dart';
import '../../../profile/presentation/widgets/profile_reviews_preview.dart';
import '../../../quotes/presentation/widgets/quote_request_builder_card.dart';
import '../../../scheduling/presentation/widgets/schedule_builder_card.dart';
import '../../../verification/domain/entities/verification.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../../verification/presentation/widgets/credential_detail_sheet.dart';
import '../../../verification/presentation/widgets/trade_credential_badges.dart';
import '../../../verification/presentation/widgets/trust_chip.dart';
import '../../domain/entities/job_application.dart';
import '../providers/applications_provider.dart';
import 'job_applicants_args.dart';

part 'applicant_detail_action_bar.dart';
part 'applicant_detail_widgets.dart';

/// Fetches a tradie's trade profile for the applicant detail screen. autoDispose
/// so each open re-fetches. Returns null on error (the screen degrades to the
/// application data it already has).
final _tradeProfileProvider = FutureProvider.autoDispose
    .family<TradeProfile?, String>((ref, userId) async {
      final res = await ref
          .read(profileRepositoryProvider)
          .getTradeProfile(userId);
      return res.fold((_) => null, (p) => p);
    });

/// First verified row of [kind], or null when absent (or when the async value
/// hasn't produced data). 2026-08-18 audit (#6): callers must ALSO check
/// `ver.hasValue` before treating null as "not verified" — while the load is
/// pending or failed the state is UNKNOWN, and the chips must render nothing
/// rather than silently downgrading a verified applicant.
Verification? _firstVerified(
  AsyncValue<List<Verification>> ver,
  VerificationKind kind,
) {
  final rows = ver.asData?.value;
  if (rows == null) return null;
  for (final v in rows) {
    if (v.kind == kind && v.isVerified) return v;
  }
  return null;
}

/// Applicant detail (design depths "1 + 2"): who they are, ✓verification,
/// rating, their quote for this job, about + stats, availability, and a bottom
/// bar to MESSAGE / shortlist / reject / hire. Reached from the Job → Applicants
/// list and the global Applicants tab.
class ApplicantDetailPage extends ConsumerWidget {
  const ApplicantDetailPage({super.key, required this.args});

  final ApplicantDetailArgs args;

  Future<void> _message(BuildContext context, WidgetRef ref) async {
    final app = args.application;
    final convId = await ref
        .read(messagingControllerProvider.notifier)
        .getOrCreateConversation(
          builderId: app.builderId,
          tradeId: app.tradeId,
          jobId: app.jobId,
        );
    if (convId == null || !context.mounted) return;
    context.push(
      '/messages/$convId',
      extra: ConversationArgs(
        conversationId: convId,
        otherName: app.tradeFullName ?? 'Tradesperson',
        jobTitle: args.jobTitle,
      ),
    );
  }

  // 2026-08-18 audit (#4): pop ONLY when the write succeeded — a failed HIRE
  // used to close the page silently, leaving the builder believing they had
  // hired someone. On failure, stay put and surface the error.
  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    ApplicationStatus status,
  ) async {
    final ok = await ref
        .read(applicationsControllerProvider.notifier)
        .updateStatus(args.application.id, status);
    if (!context.mounted) return;
    if (ok) {
      context.pop();
      return;
    }
    final error = ref.read(applicationsControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ?? "Couldn't update this application. Please try again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final app = args.application;
    final profile = ref.watch(_tradeProfileProvider(app.tradeId)).asData?.value;
    final ver = ref.watch(verificationsForUserProvider(app.tradeId));
    // U2: pass the full rows (not booleans) so the header chips can open a
    // provenance sheet with the register/as-at/expiry detail.
    final licenceVerif = _firstVerified(ver, VerificationKind.licence);
    final abnVerif = _firstVerified(ver, VerificationKind.abn);
    // 2026-08-18 audit (#6): loading/error is UNKNOWN, not "unverified" —
    // the header hides the verification chips entirely until data lands.
    final verificationsKnown = ver.hasValue;

    // Figma `JobDun-Screens` → Applicant (node 124:5916) draws the screen on
    // the plain base surface; every block on it is a bordered card, so the
    // ground has to be the surface those borders sit on.
    return Scaffold(
      backgroundColor: c.card,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar (node 124:5960): caret, then the screen name in Inter
            // Bold 24. The applicant's own name leads the identity card below,
            // so the bar names the screen, not the person.
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: AppSpacing.sm.h,
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => context.pop(),
                      // The caret is ~10dp of ink; the padding is the target.
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm.w,
                          vertical: 12.h,
                        ),
                        child: Icon(
                          AppIcons.back,
                          size: AppIconSize.md.r,
                          color: c.text1,
                        ),
                      ),
                    ),
                  ),
                  Gap(AppSpacing.md.w),
                  Expanded(
                    child: Text(
                      'Applicant',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
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

            // ── Body
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(_tradeProfileProvider(app.tradeId));
                  ref.invalidate(verificationsForUserProvider(app.tradeId));
                },
                color: c.action,
                backgroundColor: c.card,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.md.w,
                    AppSpacing.md.h,
                    AppSpacing.md.w,
                    AppSpacing.xl.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DetailHeader(
                        app: app,
                        profile: profile,
                        licenceVerif: licenceVerif,
                        abnVerif: abnVerif,
                        verificationsKnown: verificationsKnown,
                      ),
                      Gap(AppSpacing.lg.h),
                      _QuoteBlock(app: app),
                      Gap(AppSpacing.lg.h),
                      QuoteRequestBuilderCard(
                        jobId: app.jobId,
                        tradeId: app.tradeId,
                      ),
                      if (app.status == ApplicationStatus.hired) ...[
                        Gap(AppSpacing.lg.h),
                        ScheduleBuilderCard(
                          jobId: app.jobId,
                          tradeId: app.tradeId,
                        ),
                      ],
                      if (profile != null) ...[
                        Gap(AppSpacing.lg.h),
                        _StatsStrip(profile: profile),
                      ],
                      if ((profile?.about ?? '').trim().isNotEmpty) ...[
                        Gap(AppSpacing.lg.h),
                        const SectionLabel('About'),
                        Gap(12.h),
                        Text(
                          profile!.about!.trim(),
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(color: c.text1, height: 1.4),
                        ),
                      ],
                      if ((app.coverNote ?? '').trim().isNotEmpty) ...[
                        Gap(AppSpacing.lg.h),
                        const SectionLabel('Cover note'),
                        Gap(12.h),
                        Text(
                          app.coverNote!.trim(),
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(color: c.text1, height: 1.4),
                        ),
                      ],
                      // ── Availability — the deferred availability-calendar plugs
                      // in here next (table_calendar). For now: the applicant's
                      // earliest start from their application.
                      // TODO(availability-calendar): embed the tradie's
                      // TableCalendar of available days in this section.
                      Gap(AppSpacing.lg.h),
                      const SectionLabel('Availability'),
                      Gap(12.h),
                      Row(
                        children: [
                          Icon(
                            AppIcons.calendar,
                            size: AppIconSize.inline.r,
                            color: c.text2,
                          ),
                          Gap(AppSpacing.sm.w),
                          Expanded(
                            child: Text(
                              app.availableFrom != null
                                  ? 'Available from ${StringUtils.fmtDate(app.availableFrom!)}'
                                  : 'Availability not specified',
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(height: 1.0, color: c.text1),
                            ),
                          ),
                        ],
                      ),
                      // S15: the persuasive evidence — work photos + reviews —
                      // brought onto the builder's hire-decision screen.
                      if (profile != null &&
                          profile.portfolioUrls.isNotEmpty) ...[
                        Gap(AppSpacing.lg.h),
                        const SectionLabel('Portfolio'),
                        Gap(12.h),
                        PortfolioStrip(
                          urls: profile.portfolioUrls,
                          readOnly: true,
                        ),
                      ],
                      if (profile != null && profile.ratingCount > 0) ...[
                        Gap(AppSpacing.lg.h),
                        ProfileRatingBlock(
                          average: profile.averageRating,
                          count: profile.ratingCount,
                        ),
                        Gap(AppSpacing.sm.h),
                        ProfileReviewsPreview(
                          userId: app.tradeId,
                          emptyMessage: 'No reviews yet.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom action bar
            _ActionBar(
              status: app.status,
              onMessage: () => _message(context, ref),
              onShortlist: () =>
                  _setStatus(context, ref, ApplicationStatus.shortlisted),
              onReject: () =>
                  _setStatus(context, ref, ApplicationStatus.rejected),
              onHire: () => _setStatus(context, ref, ApplicationStatus.hired),
            ),
          ],
        ),
      ),
    );
  }
}
