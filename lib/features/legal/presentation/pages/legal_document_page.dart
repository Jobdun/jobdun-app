import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../domain/legal_document.dart';
import '../providers/legal_provider.dart';
import '../widgets/legal_document_view.dart';

/// Shared page for both Terms of Service and Privacy Policy.
class LegalDocumentPage extends ConsumerWidget {
  const LegalDocumentPage({super.key, required this.type});

  final LegalDocumentType type;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final docAsync = ref.watch(legalDocumentProvider(type));

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, color: c.text1, size: AppIconSize.md.r),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          type.displayTitle.toUpperCase(),
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            fontSize: 15.sp,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: c.border),
        ),
      ),
      body: docAsync.when(
        loading: () => Center(
          child: CircularProgressIndicator(color: c.action, strokeWidth: 2),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.r),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppIcons.warning,
                  color: c.urgent,
                  size: AppIconSize.hero.r,
                ),
                Gap(AppSpacing.md.h),
                Text(
                  'Could not load document.',
                  style: tt.bodyMedium!.copyWith(color: c.text2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        data: (doc) => Column(
          children: [
            // Sub-header: version + effective date
            Container(
              color: c.surface,
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w,
                vertical: 8.h,
              ),
              child: Text(
                'Version ${doc.version}  •  Effective [PLACEHOLDER — Ken to fill]',
                style: tt.labelSmall!.copyWith(color: c.text3, fontSize: 11.sp),
              ),
            ),
            Divider(height: 1, color: c.border),
            // Document content
            Expanded(child: LegalDocumentView(content: doc.content)),
          ],
        ),
      ),
    );
  }
}
