import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/gv_chip.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_switch.dart';
import '../../domain/entities/trade_search_filter.dart';

/// Filter content for `showJSheet`. Seeded from the current filter; pops with
/// the edited [TradeSearchFilter] on SHOW TRADIES (origin is preserved).
class TradeFilterSheet extends StatefulWidget {
  const TradeFilterSheet({super.key, required this.initial});

  final TradeSearchFilter initial;

  @override
  State<TradeFilterSheet> createState() => _TradeFilterSheetState();
}

class _TradeFilterSheetState extends State<TradeFilterSheet> {
  late int _radiusKm;
  late double? _minRating;
  late bool _availableOnly;

  // Rating chip options. null = Any.
  static const _ratings = <(String, double?)>[
    ('ANY', null),
    ('3+', 3),
    ('4+', 4),
    ('4.5+', 4.5),
  ];

  @override
  void initState() {
    super.initState();
    _radiusKm = widget.initial.radiusKm;
    _minRating = widget.initial.minRating;
    _availableOnly = widget.initial.availableOnly;
  }

  void _apply() {
    Navigator.of(context).pop(
      widget.initial.copyWith(
        radiusKm: _radiusKm,
        minRating: _minRating,
        clearMinRating: _minRating == null,
        availableOnly: _availableOnly,
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(
      TradeSearchFilter(
        originLat: widget.initial.originLat,
        originLng: widget.initial.originLng,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.card.r),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        AppSpacing.lg.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(AppSpacing.md.h),
            Text('FILTERS', style: tt.titleLarge!.copyWith(color: c.text1)),
            Gap(AppSpacing.lg.h),

            // ── Distance
            Text('DISTANCE', style: tt.labelMedium!.copyWith(color: c.text2)),
            Gap(AppSpacing.xs.h),
            Text(
              'Within $_radiusKm km',
              style: tt.bodyMedium!.copyWith(color: c.text1),
            ),
            Slider(
              value: _radiusKm.toDouble(),
              min: 5,
              max: 100,
              divisions: 19,
              activeColor: c.action,
              inactiveColor: c.surfaceRaised,
              label: '$_radiusKm km',
              onChanged: (v) => setState(() => _radiusKm = v.round()),
            ),
            Gap(AppSpacing.md.h),

            // ── Minimum rating
            Text(
              'MINIMUM RATING',
              style: tt.labelMedium!.copyWith(color: c.text2),
            ),
            Gap(AppSpacing.sm.h),
            Wrap(
              spacing: AppSpacing.sm.w,
              children: [
                for (final (label, value) in _ratings)
                  GvChip(
                    label: label,
                    active: _minRating == value,
                    onTap: () => setState(() => _minRating = value),
                  ),
              ],
            ),
            Gap(AppSpacing.lg.h),

            // ── Available only
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ONLY SHOW AVAILABLE',
                    style: tt.bodyMedium!.copyWith(color: c.text1),
                  ),
                ),
                JSwitch(
                  value: _availableOnly,
                  onChanged: (v) => setState(() => _availableOnly = v),
                ),
              ],
            ),
            Gap(AppSpacing.xl.h),

            // ── Actions
            Row(
              children: [
                Expanded(
                  child: JButton(
                    label: 'CLEAR',
                    variant: JButtonVariant.secondary,
                    onPressed: _clear,
                  ),
                ),
                Gap(AppSpacing.md.w),
                Expanded(
                  child: JButton(label: 'SHOW TRADIES', onPressed: _apply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
