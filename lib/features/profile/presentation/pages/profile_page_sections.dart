part of 'profile_page.dart';

// Profile header + role-specific (builder / trade) body sections, split into a
// `part` so `profile_page.dart` stays under the file-size budget. They lean on
// _InfoRow and the format helpers in profile_page_rows.dart — same library, so
// the cross-part references resolve.

// ── Profile Header ─────────────────────────────────────────────────────────────

/// Identity card at the top of the profile (Figma node 134:8681): a 40dp
/// avatar, the name, the account email, the role chip, and an edit affordance.
///
/// Replaces the old full-bleed header — a 96dp avatar with EDIT and SETTINGS
/// chips stacked beside it — which spent most of the fold on chrome. Settings
/// moved to the gear in the app bar, where the mock puts it.
class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.initials,
    required this.displayName,
    required this.email,
    required this.role,
    required this.isVerified,
    this.avatarUrl,
    this.isUploadingAvatar = false,
  });

  final String initials;
  final String displayName;
  final String email;
  final UserRole? role;

  /// Ring colour on the avatar — the one signal the compact card keeps from
  /// the old header, because "am I verified" is the question this page exists
  /// to answer.
  final bool isVerified;
  final String? avatarUrl;
  final bool isUploadingAvatar;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Semantics(
        button: true,
        label: 'Edit profile. $displayName, $email',
        excludeSemantics: true,
        child: Material(
          color: c.card,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
            side: BorderSide(color: c.border),
          ),
          child: InkWell(
            onTap: () => context.push('/profile/edit'),
            child: Padding(
              padding: EdgeInsets.all(16.r),
              child: Row(
                children: [
                  _ProfileAvatar(
                    initials: initials,
                    avatarUrl: avatarUrl,
                    isVerified: isVerified,
                    isUploading: isUploadingAvatar,
                  ),
                  Gap(12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: tt.titleSmall!.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.0,
                            color: c.text1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Gap(4.h),
                        Text(
                          email,
                          style: tt.labelMedium!.copyWith(
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            height: 1.4,
                            color: c.text2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (role != null) ...[
                          Gap(4.h),
                          // JChip already carries onAction on the orange fill —
                          // the mock's white label is 3.34:1 and would fail.
                          JChip(label: role!.label),
                        ],
                      ],
                    ),
                  ),
                  Gap(8.w),
                  Icon(AppIcons.edit, size: 24.r, color: c.text1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 40dp avatar with the verification ring. Single caller, directly above.
class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.isVerified,
    required this.isUploading,
  });

  final String initials;
  final String? avatarUrl;
  final bool isVerified;
  final bool isUploading;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final url = avatarUrl;
    final fallback = AvatarBlock(initials: initials, size: 40, circle: true);

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: isVerified ? c.action : c.border, width: 2),
      ),
      child: Stack(
        children: [
          if (url != null)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: url,
                width: 40.r,
                height: 40.r,
                fit: BoxFit.cover,
                placeholder: (_, _) => fallback,
                errorWidget: (_, _, _) => fallback,
              ),
            )
          else
            fallback,
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox.square(
                    dimension: 16.r,
                    child: CircularProgressIndicator(
                      color: c.background,
                      strokeWidth: 2,
                    ),
                  ),
                ),
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

    final companyName = _blank(p?.companyName);
    final contactName = _blank(p?.contactName);
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

    // Stats row stays jobs/hires/since (not rating). Builder rating + reviews
    // from tradies now render below the details card — S14 (20260609000001)
    // added the builder rating trigger. Jobs posted = real row count.
    final jobsPosted = ref
        .watch(builderJobsPostedCountProvider)
        .asData
        ?.value
        .toString();
    final sinceYear = abnRegisteredAt != null ? '${abnRegisteredAt.year}' : '—';

    void editProfile() => context.push('/profile/edit');

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Figma node 134:8697 — one bordered card, three columns split by
          // hairlines, each figure in its own semantic colour. Replaces the
          // three separate icon badges.
          JStatsRow(
            stats: [
              JStat(value: jobsPosted ?? '—', label: 'Jobs Posted'),
              JStat(
                value: (p?.hireCount ?? 0).toString(),
                label: 'Hires',
                valueColor: c.verified,
              ),
              // The mock reads "0"; an unverified builder has no ABR
              // registration date, so this stays an em dash. A real-looking 0
              // would claim the business is brand new (P6, 2026-08-18 audit).
              JStat(
                value: sinceYear,
                label: 'In-business',
                valueColor: c.warning,
              ),
            ],
          ),
          if (p?.id != null) ...[
            Gap(AppSpacing.sm.h),
            // S12: see exactly what a tradie sees before they apply.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/builders/${p!.id}'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    AppIcons.eyeOpen,
                    size: AppIconSize.inline.r,
                    color: c.action,
                  ),
                  Gap(6.w),
                  Text(
                    'PREVIEW PUBLIC PROFILE',
                    style: Theme.of(context).textTheme.labelMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: c.action,
                    ),
                  ),
                ],
              ),
            ),
          ],
          Gap(AppSpacing.md.h),
          // Own profile: always shown, with an Add prompt when empty so the
          // builder discovers the field. (addPrompt = owner mode.)
          ProfileAboutSection(
            about: p?.about,
            label: 'About the company',
            addPrompt: 'Add a company description so tradies trust you',
          ),
          Gap(AppSpacing.md.h),
          _ProfileDetailsCard(
            title: 'Company Details',
            children: [
              _InfoRow(
                icon: AppIcons.building,
                label: 'Company',
                value: companyName,
              ),
              _InfoRow(
                icon: AppIcons.user,
                label: 'Contact',
                value: contactName,
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
          if (p?.id != null) ...[
            Gap(AppSpacing.md.h),
            ProfileRatingBlock(average: p!.averageRating, count: p.ratingCount),
            if (p.ratingCount > 0) Gap(AppSpacing.sm.h),
            ProfileReviewsPreview(
              userId: p.id,
              emptyMessage:
                  'No reviews yet — tradies review you after a completed job.',
            ),
          ],
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
