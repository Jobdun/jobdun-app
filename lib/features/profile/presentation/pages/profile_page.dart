import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/design/widgets/avatar_block.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/j_chip.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../../../core/utils/string_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/logout_confirm_sheet.dart';
import '../../../verification/domain/entities/verification.dart';
import '../../../verification/presentation/providers/verifications_provider.dart';
import '../../../verification/presentation/widgets/verification_receipts.dart';
import '../../domain/entities/builder_profile.dart';
import '../../domain/entities/trade_profile.dart';
import '../providers/profile_provider.dart';

part 'profile_page_sections.dart';
part 'profile_page_settings.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(profileControllerProvider.notifier).loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final authState = ref.watch(authControllerProvider);
    final profileState = ref.watch(profileControllerProvider);

    final role = authState.role;
    final isBuilder = role == UserRole.builder;
    final email = authState.email ?? '';

    final displayName =
        profileState.profile?.displayName ?? StringUtils.nameFromEmail(email);
    final initials = StringUtils.initials(displayName);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _ProfileHeader(
                initials: initials,
                displayName: displayName,
                email: email,
                role: role,
                avatarUrl: profileState.profile?.avatarUrl,
                isUploadingAvatar: profileState.isUploadingAvatar,
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            SliverToBoxAdapter(
              child: JSkeletonList(
                enabled: profileState.isLoading,
                child: isBuilder
                    ? _BuilderProfile(profile: profileState.builderProfile)
                    : _TradeProfile(profile: profileState.tradeProfile),
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.md.h)),
            const SliverToBoxAdapter(child: _SettingsSection()),
            SliverToBoxAdapter(child: Gap(AppSpacing.lg.h)),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w),
                child: JButton(
                  label: 'SIGN OUT',
                  variant: JButtonVariant.secondary,
                  onPressed: () => showLogoutSheet(context, ref),
                ),
              ),
            ),
            SliverToBoxAdapter(child: Gap(AppSpacing.xl.h)),
          ],
        ),
      ),
    );
  }
}
