import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../app/router/admin_routes.dart';
import '../../../admin_shell/presentation/widgets/admin_scaffold.dart';
import '../../domain/entities/admin_user_detail.dart';
import '../providers/admin_user_detail_provider.dart';
import '../widgets/admin_user_builder_card.dart';
import '../widgets/admin_user_detail_header.dart';
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
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorCard(
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
          const Gap(40),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "COULDN'T LOAD USER",
              style: GoogleFonts.oswald(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            const Gap(8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.openSans(fontSize: 12, color: c.text2),
            ),
            const Gap(16),
            TextButton(onPressed: onRetry, child: const Text('RETRY')),
          ],
        ),
      ),
    );
  }
}
