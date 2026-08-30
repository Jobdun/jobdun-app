part of 'profile_page.dart';

// ── Trade Profile ──────────────────────────────────────────────────────────────

class _TradeProfile extends ConsumerWidget {
  const _TradeProfile({this.profile});

  final TradeProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final p = profile;

    // Same identity signal the builder card shows: the OTP-verified primary
    // phone. phone_verified_at == null → unverified, so no tick renders.
    final userProfile = ref.watch(
      profileControllerProvider.select((s) => s.profile),
    );
    final userPhone = _formatPhone(userProfile?.phone);
    final phoneVerified = userProfile?.isPhoneVerified ?? false;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final jobsDone = (p?.jobsCompleted ?? 0).toString();
    final yrsExp = p?.yearsExperience != null ? '${p!.yearsExperience}+' : '—';

    final trade = _blank(p?.displayTrade);
    final location = _blank(p?.displayLocation);
    // Verified flag derives from the new verifications table (the legacy
    // trade_profiles.is_verified column isn't written by the v2.1 wizard,
    // so reading it would leave this banner stuck on "Available for work"
    // even after a successful licence check).
    final verifs = ref.watch(myVerificationsProvider);
    final isVerified = verifs.maybeWhen(
      data: (rows) =>
          rows.any((v) => v.kind == VerificationKind.licence && v.isVerified),
      orElse: () => p?.isVerified ?? false,
    );

    // 16dp, matching _ProfileHeader above and _BuilderProfile — the trade body
    // used to sit on 20 and visibly failed to line up with the identity card.
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Same three-up figure row as the builder profile (Figma node
          // 134:8697). The old three JStatBadges were free-standing cards in a
          // Row, so an unevenly-wrapping label left them at different heights
          // and vertically centred against each other; JStatsRow is one card
          // with IntrinsicHeight columns, so the figures always line up.
          JStatsRow(
            stats: [
              JStat(value: rating, label: 'Rating'),
              JStat(
                value: jobsDone,
                label: 'Jobs Done',
                valueColor: c.verified,
              ),
              JStat(value: yrsExp, label: 'Yrs Exp', valueColor: c.warning),
            ],
          ),
          if (p?.id != null) ...[
            Gap(AppSpacing.sm.h),
            // The tradie half of S12 — see exactly what a builder sees before
            // they hire. The builder profile has had this since S12; the trade
            // side had no public view to point at until /trades/:id existed.
            _PreviewPublicProfileLink(tradeId: p!.id),
          ],
          Gap(AppSpacing.md.h),
          // Availability (real, from the profile) split from the verified
          // signal — see ProfileAvailabilityBanner.
          ProfileAvailabilityBanner(profile: p, isVerified: isVerified),
          // U3.4: profile IS credibility — the receipts card leads, right
          // under the availability banner, instead of hiding below reviews
          // at the bottom of the scroll (page-override layout).
          if (p?.id != null) ...[
            Gap(AppSpacing.md.h),
            VerificationReceipts(
              userId: p!.id,
              isOwner: true,
              showAbnRow: false,
              showLicenceRow: true,
              showWhiteCardRow: true,
              showInsuranceRow: true,
            ),
          ],
          Gap(AppSpacing.md.h),
          // Own profile: always shown with an Add prompt when empty. Sentence
          // case, because FieldLabel.section renders the string verbatim at
          // 16dp bold — the old "ABOUT" literal shouted where the builder side
          // says "About the company".
          ProfileAboutSection(
            about: p?.about,
            label: 'About you',
            addPrompt: 'Add a short bio so builders know you',
          ),
          // P4 (S9): trade as a scannable chip. Single-trade for now —
          // a multi-skill list needs a secondary_trades field (migration).
          // Keyed off `trade`, not `p != null`: a profile row whose
          // primary_trade is still blank rendered an empty chip — a bare
          // orange pill with nothing in it.
          if (trade != null) ...[
            Gap(AppSpacing.md.h),
            const FieldLabel.section('Skills'),
            Gap(AppSpacing.sm.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: [JChip(label: trade)],
            ),
          ],
          Gap(AppSpacing.md.h),
          const FieldLabel.section('Portfolio'),
          Gap(AppSpacing.sm.h),
          // Editable on the owner's own profile — the strip's ADD tile is the
          // empty-state affordance. (Public/applicant views pass readOnly:true.)
          const PortfolioStrip(),
          Gap(AppSpacing.md.h),
          _ProfileDetailsCard(
            title: 'Trade Details',
            children: [
              _InfoRow(icon: AppIcons.licence, label: 'Trade', value: trade),
              // U3.4: the self-declared "Licence: On file" row is gone — the
              // receipts card above is the only licence statement on this
              // page (it reflects the actual reviewed/verified state, not an
              // honour-system profile flag).
              _InfoRow(
                icon: AppIcons.location,
                label: 'Base suburb',
                value: location,
              ),
              // Both of these read a non-null field off a nullable profile, so
              // with no trade_profiles row yet they used to state "50 km
              // radius" and "Solo operator" as fact — the entity's constructor
              // defaults presented as the tradie's own answers. Same class of
              // bug as the builder's in-business "0" (P6, 2026-08-18 audit):
              // no row means Not set, not a plausible-looking guess.
              _InfoRow(
                icon: AppIcons.map,
                label: 'Service area',
                value: p == null ? null : '${p.serviceRadiusKm} km radius',
              ),
              _InfoRow(
                icon: AppIcons.user,
                label: 'Crew',
                value: p == null
                    ? null
                    : (p.crewSize <= 1
                          ? 'Solo operator'
                          : 'Crew of ${p.crewSize}'),
              ),
              _InfoRow(
                icon: AppIcons.budget,
                label: 'Hourly rate',
                value: _formatHourlyRate(p),
              ),
              _InfoRow(
                icon: AppIcons.phone,
                label: 'Phone',
                value: userPhone,
                verified: phoneVerified,
                onTap: userPhone == null
                    ? () => context.push('/profile/verify-phone')
                    : null,
              ),
            ],
          ),
          if (p?.id != null) ...[
            Gap(AppSpacing.md.h),
            ProfileRatingBlock(average: p!.averageRating, count: p.ratingCount),
            if (p.ratingCount > 0) Gap(AppSpacing.sm.h),
            ProfileReviewsPreview(
              userId: p.id,
              emptyMessage: 'No reviews yet — complete a job to earn one.',
            ),
          ],
        ],
      ),
    );
  }
}

/// "See what a builder sees" link, above the fold on the tradie's own profile.
///
/// Deliberately `c.actionInk`, not `c.action`: at label size the fill orange
/// is 3.34:1 and fails AA, which is what MASTER's action-vs-actionInk split
/// exists for. (The builder profile's equivalent link still uses `c.action`
/// and has the same problem — untouched here because that file is being
/// edited elsewhere.)
class _PreviewPublicProfileLink extends StatelessWidget {
  const _PreviewPublicProfileLink({required this.tradeId});

  final String tradeId;

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Semantics(
      button: true,
      label: 'Preview public profile. See what a builder sees.',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/trades/$tradeId'),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6.h),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.eyeOpen,
                size: AppIconSize.inline.r,
                color: c.actionInk,
              ),
              Gap(6.w),
              Text(
                'PREVIEW PUBLIC PROFILE',
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: c.actionInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
