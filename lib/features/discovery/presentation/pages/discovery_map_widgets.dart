part of 'discovery_map_page.dart';

// Floating pieces over the discovery map, split into a part so the page file
// stays under the size budget. Private, single-use, co-located.

// Top-left: back button + a "N TRADIES NEAR YOU" pill. Floats over the map so
// the map stays edge-to-edge.
class _MapTopBar extends StatelessWidget {
  const _MapTopBar({required this.count, this.offline = false});

  final int count;
  final bool offline;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 0),
        child: Row(
          children: [
            _CircleButton(
              icon: AppIcons.back,
              semanticLabel: 'Back',
              onTap: () => context.pop(),
            ),
            Gap(10.w),
            Flexible(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 9.h),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadius.chip.r),
                  border: Border.all(color: c.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      AppIcons.location,
                      size: AppIconSize.inline.r,
                      color: c.action,
                    ),
                    Gap(6.w),
                    Flexible(
                      child: Text(
                        count == 1
                            ? '1 TRADIE NEAR YOU'
                            : '$count TRADIES NEAR YOU',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium!.copyWith(
                          color: c.text1,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (offline) ...[Gap(8.w), const _OfflineChip()],
          ],
        ),
      ),
    );
  }
}

// Amber "OFFLINE" chip — surfaced on the map when connectivity drops so the
// grey (un-fetchable) tiles are explained rather than looking broken. Caution
// state = warning amber, never error red (MASTER).
class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(
        color: c.warningBg,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.wifiOff,
            size: AppIconSize.inline.r,
            color: c.warningTx,
          ),
          Gap(6.w),
          Text(
            'OFFLINE',
            style: tt.labelMedium!.copyWith(
              color: c.warningTx,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// Circular icon button used for both "back" and "recentre". Card fill + border
// so it reads against any tile style; M3 ripple + Semantics.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: c.card,
        shape: CircleBorder(side: BorderSide(color: c.border)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: Icon(icon, size: AppIconSize.md.r, color: c.text1),
          ),
        ),
      ),
    );
  }
}

// Bottom sheet shown when a tradie pin is tapped — who they are + how far.
class _TradiePinCard extends StatelessWidget {
  const _TradiePinCard({required this.pin});

  final TradiePin pin;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
      child: Row(
        children: [
          AvatarBlock(initials: _initials(pin.name), size: 52, circle: true),
          Gap(14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        pin.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: c.text1,
                        ),
                      ),
                    ),
                    if (pin.isVerified) ...[
                      Gap(6.w),
                      Icon(
                        AppIcons.verified,
                        size: AppIconSize.micro.r,
                        color: c.verified,
                      ),
                    ],
                  ],
                ),
                Gap(2.h),
                Text(
                  '${_titleCase(pin.primaryTrade)} · ${pin.distanceKm.toStringAsFixed(1)} km away',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                    color: c.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final n = name.trim();
  if (n.isEmpty) return '?';
  final parts = n.split(RegExp(r'\s+'));
  if (parts.length >= 2 && parts[1].isNotEmpty) {
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
  return parts[0][0].toUpperCase();
}

String _titleCase(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
