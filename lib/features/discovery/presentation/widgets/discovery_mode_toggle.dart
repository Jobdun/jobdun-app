import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/design/colors.dart';

/// TRADES / APPRENTICES segmented control above the discovery list.
///
/// The two modes are mutually exclusive on purpose. A mixed list would put a
/// first-year next to a licensed contractor and ask a builder to compare them
/// on the same figures, which is not a comparison either of them wins.
class DiscoveryModeToggle extends StatelessWidget {
  const DiscoveryModeToggle({
    super.key,
    required this.apprenticesOnly,
    required this.onChanged,
  });

  final bool apprenticesOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: EdgeInsets.fromLTRB(20.w, AppSpacing.sm.h, 20.w, 0),
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: 'TRADES',
              selected: !apprenticesOnly,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _Segment(
              label: 'APPRENTICES',
              selected: apprenticesOnly,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppRadius.chip.r),
          child: Container(
            // 48 unscaled: the WCAG 2.5.5 floor is absolute logical pixels.
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              // Dark-on-orange when selected. White on this orange is 3.33:1,
              // under the 4.5 text bar.
              color: selected ? c.action : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.chip.r),
            ),
            child: Text(
              label,
              style: tt.labelLarge!.copyWith(
                color: selected ? c.onAction : c.text1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
