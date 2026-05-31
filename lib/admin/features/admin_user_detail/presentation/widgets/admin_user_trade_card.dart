import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../domain/entities/admin_trade_profile.dart';
import 'admin_user_kv_row.dart';

/// Trade-specific profile fields card.
class AdminUserTradeCard extends StatelessWidget {
  const AdminUserTradeCard({super.key, required this.profile});

  final AdminTradeProfile profile;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('TRADE PROFILE', style: AdminText.cardLabel(c.text3)),
              if (profile.isVerified) ...[
                const Gap(8),
                Icon(AppIcons.verified, size: 14, color: c.verified),
                const Gap(4),
                Text(
                  'VERIFIED',
                  style: AdminText.eyebrow(
                    c.verifiedTx,
                  ).copyWith(letterSpacing: 1.1),
                ),
              ],
            ],
          ),
          const Gap(12),
          if (profile.fullName != null)
            AdminUserKvRow(label: 'Full Name', value: profile.fullName!),
          if (profile.primaryTrade != null)
            AdminUserKvRow(
              label: 'Primary Trade',
              value: profile.primaryTrade!,
            ),
          if (profile.yearsExperience != null)
            AdminUserKvRow(
              label: 'Years Experience',
              value: '${profile.yearsExperience}',
            ),
          if (profile.hourlyRate != null)
            AdminUserKvRow(
              label: 'Hourly Rate',
              value: '\$${profile.hourlyRate!.toStringAsFixed(2)}/hr',
            ),
          if (profile.dayRate != null)
            AdminUserKvRow(
              label: 'Day Rate',
              value: '\$${profile.dayRate!.toStringAsFixed(2)}/day',
            ),
          if (_hasLocation)
            AdminUserKvRow(label: 'Base Location', value: _locationString),
          if (profile.portfolioUrls.isNotEmpty)
            AdminUserKvRow(
              label: 'Portfolio URLs',
              value: '${profile.portfolioUrls.length} item(s)',
            ),
          if (profile.bio != null)
            AdminUserKvRow(label: 'Bio', value: profile.bio!),
          if (profile.about != null)
            AdminUserKvRow(label: 'About', value: profile.about!),
        ],
      ),
    );
  }

  bool get _hasLocation =>
      profile.baseSuburb != null ||
      profile.baseState != null ||
      profile.basePostcode != null;

  String get _locationString => [
    profile.baseSuburb,
    profile.baseState,
    profile.basePostcode,
  ].where((v) => v != null && v.isNotEmpty).join(', ');
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}
