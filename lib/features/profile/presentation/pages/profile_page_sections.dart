part of 'profile_page.dart';

// Profile header + role-specific (builder / trade) body sections, split into a
// `part` so `profile_page.dart` stays under the file-size budget. They lean on
// _InfoRow and the format helpers in profile_page_settings.dart — same library,
// so the cross-part references resolve. No behaviour change.

// ── Profile Header ─────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.displayName,
    required this.email,
    required this.role,
    this.avatarUrl,
    this.isUploadingAvatar = false,
  });

  final String initials;
  final String displayName;
  final String email;
  final UserRole? role;
  final String? avatarUrl;
  final bool isUploadingAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      color: c.card,
      padding: EdgeInsets.fromLTRB(
        20.w,
        AppSpacing.lg.h,
        20.w,
        AppSpacing.lg.h,
      ),
      child: Row(
        children: [
          Stack(
            children: [
              avatarUrl != null
                  ? ClipOval(
                      child: CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        width: 72.r,
                        height: 72.r,
                        fit: BoxFit.cover,
                        placeholder: (_, _) =>
                            AvatarBlock(initials: initials, size: 72),
                        errorWidget: (_, _, _) =>
                            AvatarBlock(initials: initials, size: 72),
                      ),
                    )
                  : AvatarBlock(initials: initials, size: 72),
              if (isUploadingAvatar)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(
                      color: Colors.white, // intentional: white-on-dark-overlay
                      strokeWidth: 2,
                    ),
                  ),
                ),
            ],
          ),
          Gap(AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: tt.titleMedium!.copyWith(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile/edit'),
                      child: Container(
                        height: 36.h,
                        padding: EdgeInsets.symmetric(horizontal: 12.w),
                        decoration: BoxDecoration(
                          color: c.surfaceRaised,
                          borderRadius: BorderRadius.circular(AppRadius.chip.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(AppIcons.edit, size: 16.r, color: c.text1),
                            Gap(6.w),
                            Text(
                              'EDIT',
                              style: tt.labelSmall!.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: c.text1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(4.h),
                Text(email, style: tt.bodyMedium!.copyWith(color: c.text3)),
                if (role != null) ...[
                  Gap(AppSpacing.sm.h),
                  JChip(label: role!.label),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Builder Profile ────────────────────────────────────────────────────────────

class _BuilderProfile extends ConsumerWidget {
  const _BuilderProfile({this.profile});

  final BuilderProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final p = profile;

    final rating = p?.averageRating?.toStringAsFixed(1) ?? '—';
    final reviews = (p?.ratingCount ?? 0).toString();
    final jobsPosted = (p?.totalJobsPosted ?? 0).toString();

    final companyName = _blank(p?.companyName);
    final abn = _formatAbn(p?.abn);
    final location = _blank(p?.displayLocation);
    final website = _blank(p?.website);

    // Profile-level identity signals — distinct from the business-level ABN
    // verification rendered in the WHAT'S BEEN CHECKED card below.
    final userProfile = ref.watch(
      profileControllerProvider.select((s) => s.profile),
    );
    final userPhone = _formatPhone(userProfile?.phone);
    final phoneVerified = userProfile?.isPhoneVerified ?? false;

    // Contact row prefers an explicit business contact_phone the builder set
    // on /profile/edit; otherwise falls back to the verified primary phone
    // so the row isn't useless on a brand-new profile. The verified tick
    // surfaces only on the fallback (the primary phone is the one we
    // actually verified — contact_phone is self-attested).
    final contactPhone = _formatPhone(p?.contactPhone);
    final contactValue = contactPhone ?? userPhone;
    final contactVerified = contactPhone == null && phoneVerified;

    // Verifications drive the right-column ABR facts (entity type, registered
    // address, in-business-since). Distinct from builder_profiles.service_*
    // which is where the user actually works — see VERIFICATION_AUDIT.md.
    final verifs = ref.watch(myVerificationsProvider);
    final abnVerification = verifs.maybeWhen<Verification?>(
      data: (rows) {
        for (final v in rows) {
          if (v.kind == VerificationKind.abn && v.isVerified) return v;
        }
        return null;
      },
      orElse: () => null,
    );
    final abnVerified = abnVerification != null;
    final entityType = abnVerification?.entityType;
    final abrState = abnVerification?.abrState;
    final abrPostcode = abnVerification?.abrPostcode;
    final abnRegisteredAt = abnVerification?.abnRegisteredAt;
    final registeredLocation = _formatRegisteredLocation(abrState, abrPostcode);
    final inBusinessSince = _formatInBusinessSince(abnRegisteredAt);

    void editProfile() => context.push('/profile/edit');

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
                value: reviews,
                label: 'Reviews',
                icon: AppIcons.messageText,
                iconColor: c.available,
              ),
              Gap(AppSpacing.sm.w),
              JStatBadge(
                value: jobsPosted,
                label: 'Jobs posted',
                icon: AppIcons.briefcase,
                iconColor: c.action,
              ),
            ],
          ),
          Gap(AppSpacing.md.h),
          JCard(
            title: 'COMPANY DETAILS',
            children: [
              _InfoRow(
                icon: AppIcons.building,
                label: 'Company',
                value: companyName,
              ),
              _InfoRow(
                icon: AppIcons.receipt,
                label: 'ABN',
                value: abn,
                verified: abnVerified,
              ),
              _InfoRow(
                icon: AppIcons.briefcase,
                label: 'Type',
                value: entityType ?? 'Company',
                verified: entityType != null,
              ),
              if (inBusinessSince != null)
                _InfoRow(
                  icon: AppIcons.calendar,
                  label: 'In business since',
                  value: inBusinessSince,
                  verified: true,
                ),
              if (registeredLocation != null)
                _InfoRow(
                  icon: AppIcons.building,
                  label: 'Registered',
                  value: registeredLocation,
                  verified: true,
                ),
              _InfoRow(
                icon: AppIcons.phone,
                label: 'Phone',
                value: contactValue,
                verified: contactVerified,
                onTap: contactValue == null ? editProfile : null,
              ),
              _InfoRow(
                icon: AppIcons.location,
                label: 'Services in',
                value: location,
                onTap: location == null ? editProfile : null,
              ),
              _InfoRow(
                icon: AppIcons.website,
                label: 'Website',
                value: website,
                onTap: website == null
                    ? editProfile
                    : () => _launchWebsite(website),
              ),
            ],
          ),
          Gap(12.h),
          if (p?.id != null)
            VerificationReceipts(
              userId: p!.id,
              isOwner: true,
              showLicenceRow: false,
            ),
        ],
      ),
    );
  }
}

// ── Trade Profile ──────────────────────────────────────────────────────────────

class _TradeProfile extends ConsumerWidget {
  const _TradeProfile({this.profile});

  final TradeProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final p = profile;

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
          // Availability / verification banner
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: 12.h,
            ),
            decoration: BoxDecoration(
              color: isVerified ? c.verifiedBg : c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: isVerified ? c.verified : c.border),
            ),
            child: Row(
              children: [
                Icon(
                  isVerified ? AppIcons.verified : AppIcons.successCircle,
                  size: 18.r,
                  color: isVerified ? c.verified : c.text3,
                ),
                Gap(10.w),
                Text(
                  isVerified ? 'Verified tradie' : 'Available for work',
                  style: tt.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isVerified ? c.verifiedTx : c.text2,
                  ),
                ),
              ],
            ),
          ),
          Gap(12.h),
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
                icon: AppIcons.budget,
                label: 'Hourly rate',
                value: _formatHourlyRate(p),
              ),
            ],
          ),
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
