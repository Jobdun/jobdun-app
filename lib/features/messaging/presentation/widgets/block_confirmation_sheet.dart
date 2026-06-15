import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../providers/inbox_safety_provider.dart';

/// Block confirmation (Phase D safety). BLOCK is the destructive primary;
/// "ALSO REPORT" hands off to the report sheet via [onAlsoReport] after this
/// sheet closes; CANCEL just dismisses.
class BlockConfirmationSheet extends ConsumerWidget {
  const BlockConfirmationSheet({
    super.key,
    required this.otherName,
    required this.blockedId,
    required this.conversationId,
    required this.onAlsoReport,
  });

  final String otherName;
  final String blockedId;
  final String conversationId;
  final VoidCallback onAlsoReport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final safety = ref.watch(inboxSafetyControllerProvider);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 16.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'BLOCK ${otherName.toUpperCase()}?',
              style: tt.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text1,
              ),
            ),
            Gap(8.h),
            Text(
              "They won't be able to send you messages. You can still see "
              'past messages and archive this thread.',
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
            if (safety.error != null) ...[
              Gap(10.h),
              Text(
                safety.error!,
                style: tt.bodySmall!.copyWith(color: c.urgent),
              ),
            ],
            Gap(16.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'BLOCK',
                variant: JButtonVariant.danger,
                isLoading: safety.isLoading,
                onPressed: safety.isLoading
                    ? null
                    : () async {
                        final ok = await ref
                            .read(inboxSafetyControllerProvider.notifier)
                            .blockUser(
                              blockedId: blockedId,
                              conversationId: conversationId,
                            );
                        if (ok && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'ALSO REPORT ${otherName.toUpperCase()}',
                variant: JButtonVariant.secondary,
                onPressed: () {
                  Navigator.of(context).pop();
                  onAlsoReport();
                },
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'CANCEL',
                variant: JButtonVariant.text,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
