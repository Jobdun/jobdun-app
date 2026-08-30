import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import 'package:jobdun/core/theme/app_icons.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/apprenticeship_stage.dart';
import '../providers/profile_provider.dart';
import '../widgets/edit_sheets/business_details_sheet.dart';
import '../widgets/edit_sheets/identity_sheet.dart';
import '../widgets/edit_sheets/location_sheet.dart';
import '../widgets/edit_sheets/rates_sheet.dart';
import '../widgets/edit_sheets/resume_sheet.dart';
import '../widgets/edit_sheets/tickets_sheet.dart';
import '../widgets/edit_sheets/trade_details_sheet.dart';

/// Edit-profile hub (setup B, 2026-06-11): section rows with current values
/// and amber "missing" flags — the hub doubles as a completeness checklist.
/// Rows open quick-edit sheets that save ONLY their section's columns
/// (TradeProfilePatch et al. — partial saves, so untouched sections can never
/// be null-wiped); About opens a full-screen editor at /profile/edit/about.

/// Which quick-edit surface a hub row opens.
enum ProfileSection {
  identity,
  tradeDetails,
  rates,
  tickets,
  resume,
  business,
  location,
  about,
}

/// Which hub rows a TRADE sees, in order.
///
/// Tickets shows for EVERY trade, not just apprentices: a qualified sparky
/// holds a White Card and an EWP licence too, and scoping it to apprentices
/// would be an arbitrary limit.
///
/// Rates is the one row apprentices lose. They are on award rates and have
/// nothing to quote, so the field is not just empty for them, it is wrong.
List<ProfileSection> hubSectionsForTrade({required bool isApprentice}) => [
  ProfileSection.identity,
  ProfileSection.tradeDetails,
  if (!isApprentice) ProfileSection.rates,
  ProfileSection.tickets,
  // Apprentices only: a qualified tradie quotes, they don't send a CV.
  if (isApprentice) ProfileSection.resume,
  ProfileSection.location,
  ProfileSection.about,
];

class ProfileEditHubPage extends ConsumerWidget {
  const ProfileEditHubPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final state = ref.watch(profileControllerProvider);
    final isBuilder = ref.watch(
      authControllerProvider.select((s) => s.role == UserRole.builder),
    );
    final tp = state.tradeProfile;
    final bp = state.builderProfile;
    final name = (state.profile?.displayName ?? '').trim();

    String orMissing(String? v) =>
        (v == null || v.trim().isEmpty) ? '' : v.trim();
    final about = orMissing(isBuilder ? bp?.about : tp?.about);
    final area = orMissing(isBuilder ? bp?.serviceSuburb : tp?.baseSuburb);
    // Design-system rate rendering: "$65–95/hr" (en-dash), "$80/hr" when equal.
    String rates = '';
    final min = tp?.hourlyRateMin;
    final max = tp?.hourlyRateMax;
    if (min != null && max != null && max != min) {
      rates = '\$${min.toStringAsFixed(0)}–${max.toStringAsFixed(0)}/hr';
    } else if (min != null) {
      rates = '\$${min.toStringAsFixed(0)}/hr';
    }
    final trade = orMissing(tp?.primaryTrade);
    final business = orMissing(bp?.companyName);
    // An apprentice's row reads "Carpenter · 2nd year"; a qualified
    // tradie's stays the bare trade.
    final stage = tp?.apprenticeshipStage;
    final tradeLine = (tp?.isApprentice ?? false) && stage != null
        ? '${tp!.displayTrade} · ${stage.label}'
        : trade;
    final ticketCount = tp?.ticketCount ?? 0;
    final ticketLine = ticketCount == 0
        ? ''
        : '$ticketCount ${ticketCount == 1 ? 'ticket' : 'tickets'}';

    _HubRowSpec specFor(ProfileSection section) => switch (section) {
      ProfileSection.identity => _HubRowSpec(
        icon: AppIcons.user,
        label: 'Identity & photo',
        value: name,
        section: section,
      ),
      ProfileSection.tradeDetails => _HubRowSpec(
        icon: AppIcons.trade,
        label: 'Trade & experience',
        value: tradeLine,
        section: section,
      ),
      ProfileSection.rates => _HubRowSpec(
        icon: AppIcons.budget,
        label: 'Rates',
        value: rates,
        section: section,
      ),
      ProfileSection.tickets => _HubRowSpec(
        icon: AppIcons.verified,
        label: 'Tickets & licences',
        value: ticketLine,
        section: section,
        optional: true,
      ),
      ProfileSection.resume => _HubRowSpec(
        icon: AppIcons.document,
        label: 'Resume',
        value: tp?.resumeFileName ?? '',
        section: section,
        optional: true,
      ),
      ProfileSection.business => _HubRowSpec(
        icon: AppIcons.building,
        label: 'Business details',
        value: business,
        section: section,
      ),
      ProfileSection.location => _HubRowSpec(
        icon: AppIcons.location,
        label: isBuilder ? 'Service location' : 'Base location',
        value: area,
        section: section,
      ),
      ProfileSection.about => _HubRowSpec(
        icon: AppIcons.document,
        label: 'About',
        value: about,
        section: section,
      ),
    };

    // The section list IS the row order. Exhaustive switch above, so adding a
    // ProfileSection value fails to compile until it has a row.
    final sections = isBuilder
        ? const [
            ProfileSection.identity,
            ProfileSection.business,
            ProfileSection.location,
            ProfileSection.about,
          ]
        : hubSectionsForTrade(isApprentice: tp?.isApprentice ?? false);
    final rows = sections.map(specFor).toList();

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, 8.h, 20.w, 12.h),
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
                      eyebrow: 'EDIT PROFILE',
                      title: 'Your details',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 24.h),
                children: [
                  for (final row in rows) ...[_HubRow(spec: row), Gap(8.h)],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubRowSpec {
  const _HubRowSpec({
    required this.icon,
    required this.label,
    required this.value,
    required this.section,
    this.optional = false,
  });

  final IconData icon;
  final String label;

  /// Current value preview; empty = not filled in yet → amber MISSING flag.
  final String value;

  /// Which quick-edit sheet/page the row opens.
  final ProfileSection section;

  /// True for rows where blank is a legitimate end state, not an omission.
  /// Holding no tickets is a real answer a first-year cannot 'fix', so an
  /// amber MISSING flag there would be permanent and unearned.
  final bool optional;
}

class _HubRow extends StatelessWidget {
  const _HubRow({required this.spec});

  final _HubRowSpec spec;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final missing = spec.value.isEmpty && !spec.optional;
    return Semantics(
      button: true,
      label:
          '${spec.label}: ${missing ? 'not filled in yet' : spec.value}. '
          'Opens editor.',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        onTap: () => switch (spec.section) {
          ProfileSection.identity => showJSheet<bool>(
            context: context,
            builder: (_) => const IdentitySheet(),
          ),
          ProfileSection.tradeDetails => showJSheet<bool>(
            context: context,
            builder: (_) => const TradeDetailsSheet(),
          ),
          ProfileSection.business => showJSheet<bool>(
            context: context,
            builder: (_) => const BusinessDetailsSheet(),
          ),
          ProfileSection.location => showJSheet<bool>(
            context: context,
            builder: (_) => const LocationSheet(),
          ),
          ProfileSection.rates => showJSheet<bool>(
            context: context,
            builder: (_) => const RatesSheet(),
          ),
          ProfileSection.tickets => showTicketsSheet(context),
          ProfileSection.resume => showResumeSheet(context),
          ProfileSection.about => context.push('/profile/edit/about'),
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: missing ? c.warning : c.border),
          ),
          child: Row(
            children: [
              Icon(spec.icon, size: AppIconSize.md.r, color: c.text2),
              Gap(12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spec.label,
                      style: tt.titleSmall!.copyWith(color: c.text1),
                    ),
                    Gap(2.h),
                    if (missing)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: c.warningBg,
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'MISSING',
                          style: tt.labelSmall!.copyWith(
                            letterSpacing: 0.6,
                            color: c.warningTx,
                          ),
                        ),
                      )
                    else
                      Text(
                        spec.value.isEmpty ? 'None yet' : spec.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall!.copyWith(color: c.text3),
                      ),
                  ],
                ),
              ),
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.inline.r,
                color: c.text3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
