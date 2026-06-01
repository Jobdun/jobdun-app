import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';

/// A "not wired yet" card for roadmap admin pages: a section label, a sentence
/// describing what it becomes, and a single disabled [action]
/// ([AdminPlaceholderAction]). Same chrome as the live detail cards so the
/// placeholder reads as part of the product, not a broken screen.
class AdminRoadmapCard extends StatelessWidget {
  const AdminRoadmapCard({
    super.key,
    required this.label,
    required this.note,
    required this.action,
  });

  /// All-caps card header, e.g. 'TRANSACTIONS'.
  final String label;

  /// One sentence on what the surface becomes when wired.
  final String note;

  /// A single disabled action (pass an [AdminPlaceholderAction]).
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: AdminText.cardLabel(c.text3)),
              const Spacer(),
              Text(
                'NOT WIRED',
                style: AdminText.eyebrow(c.text3).copyWith(letterSpacing: 1.2),
              ),
            ],
          ),
          const Gap(12),
          Text(note, style: AdminText.value(c.text2).copyWith(height: 1.5)),
          const Gap(16),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(width: 170, child: action),
          ),
        ],
      ),
    );
  }
}
