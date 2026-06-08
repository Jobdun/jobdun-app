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
    final hasLicence = p?.hasLicence ?? false;
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JStatBadge(
                value: rating,
                label: 'Rating',
                icon: AppIcons.star,
                iconColor: c.star,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: jobsDone,
                label: 'Jobs done',
                icon: AppIcons.successCircle,
                iconColor: c.verified,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: yrsExp,
                label: 'Yrs exp',
                icon: AppIcons.award,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          // Availability (real, from the profile) split from the verified
          // signal — see ProfileAvailabilityBanner.
          ProfileAvailabilityBanner(profile: p, isVerified: isVerified),
          Gap(AppSpacing.md.h),
          // Own profile: always shown with an Add prompt when empty.
          ProfileAboutSection(
            about: p?.about,
            label: 'ABOUT',
            addPrompt: 'Add a short bio so builders know you',
          ),
          Gap(AppSpacing.md.h),
          const FieldLabel('PORTFOLIO'),
          Gap(AppSpacing.sm.h),
          // Editable on the owner's own profile — the strip's ADD tile is the
          // empty-state affordance. (Public/applicant views pass readOnly:true.)
          const PortfolioStrip(),
          Gap(AppSpacing.md.h),
          JCard(
            title: 'TRADE DETAILS',
            children: [
              _InfoRow(icon: AppIcons.licence, label: 'Trade', value: trade),
              _InfoRow(
                icon: AppIcons.document,
                label: 'Licence',
                value: hasLicence ? 'On file' : null,
              ),
              _InfoRow(
                icon: AppIcons.location,
                label: 'Base suburb',
                value: location,
              ),
              _InfoRow(
                icon: AppIcons.map,
                label: 'Service area',
                value: '${p?.serviceRadiusKm ?? 50} km radius',
              ),
              _InfoRow(
                icon: AppIcons.user,
                label: 'Crew',
                value: (p?.crewSize ?? 1) <= 1
                    ? 'Solo operator'
                    : 'Crew of ${p!.crewSize}',
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
          Gap(12.h),
          if (p?.id != null)
            VerificationReceipts(
              userId: p!.id,
              isOwner: true,
              showAbnRow: false,
              showLicenceRow: true,
            ),
        ],
      ),
    );
  }
}
