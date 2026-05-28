import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../domain/entities/admin_user_detail.dart';

/// Large avatar + display name + role pill + verified tick + id + created.
class AdminUserDetailHeader extends StatelessWidget {
  const AdminUserDetailHeader({super.key, required this.detail});

  final AdminUserDetail detail;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Avatar(url: detail.avatarUrl, name: detail.displayName),
        const Gap(20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      detail.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.oswald(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: c.text1,
                      ),
                    ),
                  ),
                  if (detail.trade?.isVerified == true) ...[
                    const Gap(8),
                    Icon(AppIcons.verified, size: 18, color: c.verified),
                  ],
                  if (detail.isDeleted) ...[
                    const Gap(8),
                    _StatusPill(
                      label: 'DELETED',
                      bg: c.urgentBg,
                      tx: c.urgentTx,
                    ),
                  ],
                ],
              ),
              const Gap(4),
              Row(
                children: [
                  _StatusPill(
                    label: detail.role.toUpperCase(),
                    bg: c.surfaceRaised,
                    tx: c.text2,
                  ),
                ],
              ),
              const Gap(6),
              Text(
                'ID: ${detail.id}',
                style: GoogleFonts.openSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.text3,
                ),
              ),
              Text(
                'Joined ${DateFormat('d MMM y').format(detail.createdAt)}',
                style: GoogleFonts.openSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: c.text3,
                ),
              ),
            ],
          ),
        ),
      ],
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
        width: 72,
        height: 72,
        child: (url != null && url!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                errorWidget: (ctx, url0, err) => _fallback(c, initial),
                placeholder: (ctx, _) => _fallback(c, initial),
              )
            : _fallback(c, initial),
      ),
    );
  }

  Widget _fallback(JColors colors, String letter) => Container(
    color: colors.surfaceRaised,
    alignment: Alignment.center,
    child: Text(
      letter,
      style: GoogleFonts.oswald(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: colors.text2,
      ),
    ),
  );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.tx});
  final String label;
  final Color bg;
  final Color tx;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: GoogleFonts.openSans(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: tx,
        ),
      ),
    );
  }
}
