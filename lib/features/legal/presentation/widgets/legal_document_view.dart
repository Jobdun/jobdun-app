import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/colors.dart';

class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({super.key, required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Markdown(
      data: content,
      selectable: true,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg.w,
        vertical: AppSpacing.md.h,
      ),
      styleSheet: MarkdownStyleSheet(
        h1: tt.headlineMedium!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w700,
          fontSize: 22.sp,
          letterSpacing: 0.3,
        ),
        h2: tt.titleLarge!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w700,
          fontSize: 17.sp,
        ),
        h3: tt.titleMedium!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w600,
          fontSize: 15.sp,
        ),
        p: tt.bodyMedium!.copyWith(
          color: c.text2,
          fontSize: 14.sp,
          height: 1.6,
        ),
        strong: tt.bodyMedium!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w700,
          fontSize: 14.sp,
        ),
        em: tt.bodyMedium!.copyWith(
          color: c.text2,
          fontStyle: FontStyle.italic,
          fontSize: 14.sp,
        ),
        listBullet: tt.bodyMedium!.copyWith(color: c.action, fontSize: 14.sp),
        blockquote: tt.bodySmall!.copyWith(
          color: c.text3,
          fontStyle: FontStyle.italic,
          fontSize: 12.sp,
        ),
        blockquoteDecoration: BoxDecoration(
          border: Border(left: BorderSide(color: c.action, width: 3)),
          color: c.surface,
        ),
        blockquotePadding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h),
        horizontalRuleDecoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: c.border, width: 1)),
        ),
        tableHead: tt.labelSmall!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w700,
          fontSize: 12.sp,
        ),
        tableBody: tt.bodySmall!.copyWith(color: c.text2, fontSize: 12.sp),
        tableHeadAlign: TextAlign.left,
        tableBorder: TableBorder.all(color: c.border, width: 1),
        tableCellsPadding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
        code: tt.bodySmall!.copyWith(
          color: c.action,
          backgroundColor: c.surface,
          fontSize: 12.sp,
          fontFamily: 'monospace',
        ),
        codeblockDecoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: c.border),
        ),
        a: tt.bodyMedium!.copyWith(
          color: c.action,
          decoration: TextDecoration.underline,
          decorationColor: c.action,
          fontSize: 14.sp,
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href == null) return;
        final uri = Uri.tryParse(href);
        if (uri == null) return;
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        }
      },
    );
  }
}
