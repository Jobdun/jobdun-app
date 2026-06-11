import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';

/// One provenance line in the credential detail sheet.
typedef CredentialDetailRow = ({IconData icon, String text});

/// U2.2: a trust badge must answer "what was checked, when, until when" one
/// tap away. Shows ONLY what the minimized public projection already exposes —
/// never numbers, insurers, or documents.
Future<void> showCredentialDetailSheet(
  BuildContext context, {
  required String title,
  required List<CredentialDetailRow> rows,
  String? blurb,
}) {
  return showJSheet<void>(
    context: context,
    expand: false,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) =>
        _CredentialDetailSheetBody(title: title, rows: rows, blurb: blurb),
  );
}

class _CredentialDetailSheetBody extends StatelessWidget {
  const _CredentialDetailSheetBody({
    required this.title,
    required this.rows,
    this.blurb,
  });

  final String title;
  final List<CredentialDetailRow> rows;
  final String? blurb;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: c.border,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Gap(16.h),
            Text(
              title,
              style: tt.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
            ),
            if (blurb != null) ...[
              Gap(6.h),
              Text(blurb!, style: tt.bodySmall!.copyWith(color: c.text3)),
            ],
            Gap(16.h),
            for (final row in rows) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(row.icon, size: AppIconSize.inline.r, color: c.text2),
                  Gap(10.w),
                  Expanded(
                    child: Text(
                      row.text,
                      style: tt.bodyMedium!.copyWith(color: c.text1),
                    ),
                  ),
                ],
              ),
              Gap(10.h),
            ],
          ],
        ),
      ),
    );
  }
}
