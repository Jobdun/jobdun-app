part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour change.

// Top-left chip: "NEAR PARRAMATTA, NSW · 5 KM". Tells the user exactly which
// location the radius circle is anchored on and how far out the pins reach.
// Pure presentation — the actual circle is rendered by the CircleLayer in
// _MapView.build.
class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.placeLabel, required this.radiusKm});

  final String placeLabel;
  final double radiusKm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Trim a trailing ", NSW" / ", VIC" etc. — the chip is already tight on
    // horizontal real estate when paired with the style/recenter column.
    final shortPlace = placeLabel.split(',').first.trim().toUpperCase();
    final radiusText = radiusKm == radiusKm.roundToDouble()
        ? '${radiusKm.toInt()} KM'
        : '${radiusKm.toStringAsFixed(1)} KM';
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.location, size: AppIconSize.inline.r, color: c.action),
          Gap(6.w),
          // Capped + ellipsized so a long place name can never run under the
          // top-right control column on narrow screens.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 140.w),
            child: Text(
              'NEAR $shortPlace',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Gap(8.w),
          Container(width: 1, height: 12.h, color: c.border),
          Gap(8.w),
          Text(
            radiusText,
            style: tt.labelSmall!.copyWith(
              color: c.action,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Compact corner button — flat, hard edges, brand-orange icon on surface.
class _MapStyleButton extends StatelessWidget {
  const _MapStyleButton({required this.current, required this.onTap});

  final _MapStyle current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // Icon-only (2026-06-11): the style NAME ("VOYAGER") made the button
        // wide enough to collide with a long place chip ("NEAR MANILA…") on
        // narrow screens. The layers glyph alone is the convention (Google
        // Maps); the style sheet it opens still names every option.
        child: Semantics(
          label: 'Map style: ${current.label}. Opens style picker.',
          button: true,
          child: Container(
            width: 40.r,
            height: 40.r,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              border: Border.all(color: c.border, width: 1),
              borderRadius: BorderRadius.circular(2.r),
            ),
            child: Icon(
              AppIcons.mapLayer,
              size: AppIconSize.md.r,
              color: c.action,
            ),
          ),
        ),
      ),
    );
  }
}

Future<_MapStyle?> _showStyleSheet(BuildContext context, _MapStyle current) {
  return showJSheet<_MapStyle>(
    context: context,
    builder: (_) => _MapStyleSheet(current: current),
  );
}

class _MapStyleSheet extends StatelessWidget {
  const _MapStyleSheet({required this.current});

  final _MapStyle current;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(2.r)),
          border: Border(top: BorderSide(color: c.action, width: 3)),
        ),
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'MAP STYLE',
              style: tt.headlineSmall!.copyWith(
                color: c.text1,
                letterSpacing: 0.5,
              ),
            ),
            Gap(4.h),
            Text(
              'Pick the look that fits how you read maps.',
              style: tt.bodySmall!.copyWith(color: c.text2),
            ),
            Gap(16.h),
            for (final style in _MapStyle.values) ...[
              _MapStyleRow(
                style: style,
                selected: style == current,
                onTap: () => Navigator.of(context).pop(style),
              ),
              if (style != _MapStyle.values.last) Gap(8.h),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapStyleRow extends StatelessWidget {
  const _MapStyleRow({
    required this.style,
    required this.selected,
    required this.onTap,
  });

  final _MapStyle style;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          border: Border.all(
            color: selected ? c.action : c.border,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(2.r),
        ),
        child: Row(
          children: [
            Container(
              width: 32.r,
              height: 32.r,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? c.action : c.surface,
                borderRadius: BorderRadius.circular(2.r),
              ),
              child: Icon(
                AppIcons.mapLayer,
                size: AppIconSize.inline.r,
                color: selected
                    ? Colors
                          .white // intentional: white-on-action
                    : c.text2,
              ),
            ),
            Gap(12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    style.label,
                    style: tt.labelLarge!.copyWith(
                      color: c.text1,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    style.description,
                    style: tt.bodySmall!.copyWith(color: c.text2),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                AppIcons.successCircleFilled,
                size: AppIconSize.md.r,
                color: c.action,
              ),
          ],
        ),
      ),
    );
  }
}

// Locate-me button. Tap when we already have a fix → recentre the map.
// Tap when we don't → kick off the full request flow (rationale → prompt →
// fetch). While in-flight, swap the icon for a spinner so it can't be
// double-tapped.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({
    required this.isLoading,
    required this.hasLocation,
    required this.onTap,
  });

  final bool isLoading;
  final bool hasLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Container(
          width: 36.r,
          height: 36.r,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: c.border, width: 1),
            borderRadius: BorderRadius.circular(2.r),
          ),
          child: isLoading
              ? SizedBox.square(
                  dimension: 14.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.action,
                  ),
                )
              : Icon(
                  hasLocation ? AppIcons.gpsFilled : AppIcons.gps,
                  size: AppIconSize.md.r,
                  color: c.action,
                ),
        ),
      ),
    );
  }
}

// Inline banner surfaced at the bottom of the map when location can't be
// fetched. Copy + CTA change per failure mode so the user knows exactly
// what to do (vs a generic "permission needed" message).
class _LocationStatusBanner extends StatelessWidget {
  const _LocationStatusBanner({
    required this.status,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final _LocationStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final (title, body, ctaLabel, ctaAction) = switch (status) {
      _LocationStatus.serviceDisabled => (
        'LOCATION OFF',
        'Turn on device location to see jobs near you.',
        'RETRY',
        onRetry,
      ),
      _LocationStatus.denied => (
        'LOCATION DENIED',
        'Allow location access to centre the map on you.',
        'ALLOW',
        onRetry,
      ),
      _LocationStatus.deniedForever => (
        'LOCATION BLOCKED',
        "Permission is blocked. Enable it in your phone's settings.",
        'SETTINGS',
        onOpenSettings,
      ),
      _LocationStatus.error => (
        "COULDN'T LOCATE",
        'Take a moment, then try again.',
        'RETRY',
        onRetry,
      ),
      _ => ('', '', '', onRetry),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            AppIcons.locationUnavailable,
            size: AppIconSize.md.r,
            color: c.action,
          ),
          Gap(12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tt.labelLarge!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                Gap(2.h),
                Text(body, style: tt.bodySmall!.copyWith(color: c.text2)),
              ],
            ),
          ),
          Gap(8.w),
          TextButton(
            onPressed: ctaAction,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            child: Text(
              ctaLabel,
              style: tt.labelLarge!.copyWith(
                color: c.action,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
