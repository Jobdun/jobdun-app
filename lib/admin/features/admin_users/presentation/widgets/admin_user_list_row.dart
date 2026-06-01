import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../../../app/placeholders/admin_status_tag.dart';
import '../../../../app/placeholders/placeholder_models.dart';
import '../../domain/entities/admin_user_row.dart';

class AdminUserListRow extends StatelessWidget {
  const AdminUserListRow({super.key, required this.row});

  final AdminUserRow row;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Row(
        children: [
          _Avatar(url: row.avatarUrl, name: row.displayName),
          const Gap(14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        row.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AdminText.body(
                          c.text1,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (row.isVerified) ...[
                      const Gap(6),
                      Icon(AppIcons.verified, size: 14, color: c.action),
                    ],
                  ],
                ),
                const Gap(2),
                Text(
                  row.role.toUpperCase(),
                  style: AdminText.eyebrow(
                    c.text3,
                  ).copyWith(letterSpacing: 1.2),
                ),
                const Gap(6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    AdminStatusTag(
                      label: SubscriptionTier.placeholderDefault.label,
                      tooltip: 'Subscription tier — ${AdminPhase.billing}',
                    ),
                    AdminStatusTag(
                      label: UserModerationStatus.placeholderDefault.label,
                      tooltip: 'Moderation status — ${AdminPhase.moderation}',
                    ),
                    AdminStatusTag(
                      label: '—',
                      icon: AppIcons.warning,
                      tooltip: 'Open reports — ${AdminPhase.moderation}',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: AdminText.caption(
              c.text2,
            ).copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return ClipOval(
      child: SizedBox(
        width: 36,
        height: 36,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (ctx, url, err) => _initialFallback(c, initial),
                placeholder: (ctx, url) => _initialFallback(c, initial),
              )
            : _initialFallback(c, initial),
      ),
    );
  }

  Widget _initialFallback(JColors c, String letter) => Container(
    color: c.surfaceRaised,
    alignment: Alignment.center,
    child: Text(
      letter,
      style: AdminText.dialogTitle(
        c.text2,
      ).copyWith(fontSize: 16, letterSpacing: 0),
    ),
  );
}
