import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
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
                        style: GoogleFonts.openSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
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
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: c.text3,
                  ),
                ),
              ],
            ),
          ),
          Text(
            DateFormat('d MMM y').format(row.createdAt),
            style: GoogleFonts.openSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c.text2,
            ),
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
      style: GoogleFonts.oswald(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: c.text2,
      ),
    ),
  );
}
