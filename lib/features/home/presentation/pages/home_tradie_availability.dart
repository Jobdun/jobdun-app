part of 'home_page.dart';

// Tradie home — "open for work" availability bar (direction E spine). Reads
// trade_profiles.is_available, toggles it through the profile controller, and
// shows the off-the-clock state inline (list stays visible — going off only
// hides the tradie from builders, it doesn't hide jobs). Optimistic with
// rollback so the switch feels instant.
class _TradieAvailabilityBar extends ConsumerStatefulWidget {
  const _TradieAvailabilityBar();

  @override
  ConsumerState<_TradieAvailabilityBar> createState() =>
      _TradieAvailabilityBarState();
}

class _TradieAvailabilityBarState
    extends ConsumerState<_TradieAvailabilityBar> {
  bool? _optimistic;
  bool _saving = false;

  Future<void> _toggle(bool v) async {
    setState(() {
      _optimistic = v;
      _saving = true;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .setTradeAvailability(v);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (!ok) _optimistic = !v; // roll back the optimistic flip
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Couldn't update availability. Tap to try again."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final fromProfile = ref.watch(
      profileControllerProvider.select((s) => s.tradeProfile?.isAvailable),
    );
    final open = _optimistic ?? fromProfile ?? true;

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, AppSpacing.lg.h),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card.r),
          border: Border.all(color: open ? c.verified : c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 10.r,
              height: 10.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: open ? c.verified : c.text3,
              ),
            ),
            Gap(AppSpacing.sm.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    open ? 'OPEN FOR WORK' : 'OFF THE CLOCK',
                    style: tt.titleMedium!.copyWith(
                      color: open ? c.verifiedTx : c.text2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Gap(2.h),
                  Text(
                    open
                        ? 'Builders can find you in searches.'
                        : "Hidden from builders until you go on.",
                    style: tt.bodySmall!.copyWith(color: c.text3),
                  ),
                ],
              ),
            ),
            Gap(AppSpacing.sm.w),
            JSwitch(value: open, onChanged: _saving ? null : _toggle),
          ],
        ),
      ),
    );
  }
}
