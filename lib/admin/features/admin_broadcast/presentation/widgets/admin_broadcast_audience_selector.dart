import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';
import '../../domain/entities/broadcast_audience.dart';

/// AUDIENCE picker — a labelled dropdown over the four broadcast audiences.
/// The compose page owns the selected value; this widget only renders + reports
/// changes.
class AdminBroadcastAudienceSelector extends StatelessWidget {
  const AdminBroadcastAudienceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final BroadcastAudience value;
  final ValueChanged<BroadcastAudience> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('AUDIENCE', style: AdminText.labelMd(c.text2)),
        const Gap(8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: c.borderStrong),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<BroadcastAudience>(
              value: value,
              isExpanded: true,
              dropdownColor: c.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              icon: Icon(AppIcons.chevronDown, size: 18, color: c.text2),
              style: AdminText.input(c.text1),
              items: [
                for (final a in BroadcastAudience.values)
                  DropdownMenuItem<BroadcastAudience>(
                    value: a,
                    child: Text(a.label, style: AdminText.input(c.text1)),
                  ),
              ],
              onChanged: (next) {
                if (next != null) onChanged(next);
              },
            ),
          ),
        ),
      ],
    );
  }
}
