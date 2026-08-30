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
      padding: EdgeInsets.fromLTRB(AppSpacing.md.w, 0, AppSpacing.md.w, 0),
      child: Container(
        padding: EdgeInsets.all(AppSpacing.md.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // The title stays put and the switch carries the state —
                  // Figma node 140:13675. The subtitle still swaps, because
                  // "hidden from builders" is the consequence a tradie needs
                  // spelled out, not inferred from a toggle position.
                  Text(
                    'Open for work',
                    style: tt.titleMedium!.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: c.text1,
                    ),
                  ),
                  Gap(AppSpacing.xs.h),
                  Text(
                    open
                        ? 'Builders can find you in searches'
                        : 'Hidden from builders until you go on',
                    style: tt.bodySmall!.copyWith(
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      height: 1.4,
                      color: c.text2,
                    ),
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
