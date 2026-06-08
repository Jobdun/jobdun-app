part of 'home_page.dart';

// GENERATED-SPLIT: part of home_page.dart (file-size budget). No behaviour
// change. Status overlays for the tradie job map (_MapView): back button,
// coverage hint, offline pill, and the empty "no pins" note.

// Circular icon button for the job map's back control. Card fill + border so it
// reads against any tile style; M3 ripple + Semantics. Mirrors the discovery
// map's _CircleButton so both maps' chrome feels identical.
class _MapCircleButton extends StatelessWidget {
  const _MapCircleButton({
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

// "SHOWING 12 OF 18 NEARBY" — shown when some feed jobs lack coordinates so the
// map plots fewer pins than the list. Makes the gap explicit instead of silent.
// Same flat chip language as _RadiusChip.
class _MapCoveragePill extends StatelessWidget {
  const _MapCoveragePill({required this.plotted, required this.total});

  final int plotted;
  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
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
          Text(
            'SHOWING $plotted OF $total NEARBY',
            style: tt.labelSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Offline guardrail for the job map — tiles can't fetch, so the basemap greys
// out. Caution amber (not error red), matching the discovery map's treatment.
// Pins still render from in-memory feed state.
class _MapOfflinePill extends StatelessWidget {
  const _MapOfflinePill();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.warning, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.wifiOff, size: AppIconSize.inline.r, color: c.warning),
          Gap(6.w),
          Text(
            'OFFLINE · TILES MAY NOT LOAD',
            style: tt.labelSmall!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

// Centered, non-blocking note when jobs exist in the feed but none have a pin
// location (legacy rows / freehand-fallback). The list still has them, so point
// the user there. Caution amber, flat surface card (MASTER: no blur/shadow).
class _MapNoPinsNote extends StatelessWidget {
  const _MapNoPinsNote();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 32.w),
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(2.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            AppIcons.location,
            size: AppIconSize.feature.r,
            color: c.warning,
          ),
          Gap(10.h),
          Text(
            'NO MAP PINS YET',
            style: tt.labelLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
          Gap(4.h),
          Text(
            "These jobs don't have a pin location. Switch to the list to see "
            'them.',
            textAlign: TextAlign.center,
            style: tt.bodySmall!.copyWith(color: c.text2, height: 1.5),
          ),
        ],
      ),
    );
  }
}
