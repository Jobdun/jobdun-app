import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../app/widgets/admin_error_state.dart';
import '../../../../app/widgets/admin_list_skeleton.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_user_detail.dart';
import '../providers/admin_user_detail_provider.dart';
import '../widgets/admin_user_builder_card.dart';
import '../widgets/admin_user_detail_header.dart';
import '../widgets/admin_user_moderation_card.dart';
import '../widgets/admin_user_profile_card.dart';
import '../widgets/admin_user_trade_card.dart';
import '../widgets/admin_user_verifications_card.dart';

class AdminUserDetailPage extends ConsumerWidget {
  const AdminUserDetailPage({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(adminUserDetailProvider(userId));

    return AdminScaffold(
      title: 'USER DETAIL',
      activeRoute: AdminRoutes.users,
      child: async.when(
        loading: () => const AdminListSkeleton(rows: 5),
        error: (err, _) => AdminErrorState(
          title: "COULDN'T LOAD USER",
          message: err.toString(),
          onRetry: () => ref.invalidate(adminUserDetailProvider(userId)),
        ),
        data: (detail) => _DetailBody(detail: detail),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail});

  final AdminUserDetail detail;

  /// Only the subprofile matching the user's current `role` is shown.
  /// Mobile-facing RLS (`builder_profiles_select_authenticated` /
  /// `trade_profiles_select_authenticated` in 20260520000003) already hides
  /// orphan subprofile rows from other-role users; the admin-read policies
  /// from 20260528000001 don't carry that guard, so we apply the same
  /// rule at the UI layer until the data-cleanup option ships.
  @override
  Widget build(BuildContext context) {
    final showBuilder = detail.role == 'builder' && detail.builder != null;
    final showTrade = detail.role == 'trade' && detail.trade != null;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _BackToUsers(),
          const Gap(16),
          AdminUserDetailHeader(detail: detail),
          const Gap(24),
          AdminUserProfileCard(detail: detail),
          if (showBuilder) ...[
            const Gap(16),
            AdminUserBuilderCard(profile: detail.builder!),
          ],
          if (showTrade) ...[
            const Gap(16),
            AdminUserTradeCard(profile: detail.trade!),
          ],
          const Gap(16),
          AdminUserVerificationsCard(verifications: detail.verifications),
          const Gap(16),
          const AdminUserModerationCard(),
          const Gap(40),
        ],
      ),
    );
  }
}

class _BackToUsers extends StatelessWidget {
  const _BackToUsers();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => context.go(AdminRoutes.users),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back, size: 16, color: c.text2),
                const Gap(8),
                Text('BACK TO USERS', style: AdminText.label(c.text2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
