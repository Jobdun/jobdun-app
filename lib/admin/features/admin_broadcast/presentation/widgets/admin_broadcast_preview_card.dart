import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_typography.dart';
import '../../../../../core/theme/app_icons.dart';

/// Renders the exact notification card a recipient will see for a broadcast —
/// a bell glyph + "New from Jobdun" eyebrow, the title, and the message body.
/// Empty title/body fall back to muted placeholders so the card never collapses
/// while the admin is still typing.
class AdminBroadcastPreviewCard extends StatelessWidget {
  const AdminBroadcastPreviewCard({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hasTitle = title.trim().isNotEmpty;
    final hasBody = body.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: c.actionBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  AppIcons.notification,
                  size: 16,
                  color: c.actionInk,
                ),
              ),
              const Gap(10),
              Text('NEW FROM JOBDUN', style: AdminText.eyebrow(c.text2)),
            ],
          ),
          const Gap(12),
          Text(
            hasTitle ? title.trim() : 'Notification title',
            style: AdminText.bodyStrong(hasTitle ? c.text1 : c.text3),
          ),
          const Gap(4),
          Text(
            hasBody ? body.trim() : 'Your message will appear here.',
            style: AdminText.value(hasBody ? c.text2 : c.text3),
          ),
        ],
      ),
    );
  }
}
