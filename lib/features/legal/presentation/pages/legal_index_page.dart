import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../domain/legal_document.dart';
import '../providers/legal_provider.dart';

class LegalIndexPage extends ConsumerWidget {
  const LegalIndexPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final versionsAsync = ref.watch(legalVersionsProvider);
    final acceptedAsync = ref.watch(lastAcceptedVersionsProvider);

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
          'LEGAL',
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: c.border),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.all(AppSpacing.md.r),
        children: [
          Gap(AppSpacing.sm.h),
          _LegalDocSection(
            c: c,
            tt: tt,
            versionsAsync: versionsAsync,
            acceptedAsync: acceptedAsync,
          ),
          Gap(AppSpacing.xl.h),
          Center(
            child: Text(
              'Jobdun Pty Ltd — ABN [PLACEHOLDER]\nAll rights reserved.',
              style: tt.labelSmall!.copyWith(color: c.text3),
              textAlign: TextAlign.center,
            ),
          ),
          Gap(AppSpacing.lg.h),
        ],
      ),
    );
  }
}

class _LegalDocSection extends StatelessWidget {
  const _LegalDocSection({
    required this.c,
    required this.tt,
    required this.versionsAsync,
    required this.acceptedAsync,
  });

  final JColors c;
  final TextTheme tt;
  final AsyncValue<Map<String, String>> versionsAsync;
  final AsyncValue<Map<String, String>> acceptedAsync;

  @override
  Widget build(BuildContext context) {
    final currentVersions = versionsAsync.asData?.value ?? {};
    final acceptedVersions = acceptedAsync.asData?.value ?? {};

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md.w,
              14.h,
              AppSpacing.md.w,
              10.h,
            ),
            child: Text(
              'DOCUMENTS',
              style: tt.labelSmall!.copyWith(
                letterSpacing: 0.12 * 11,
                color: c.text3,
              ),
            ),
          ),
          Divider(height: 1, color: c.border),
          for (final type in LegalDocumentType.values) ...[
            _DocTile(
              c: c,
              tt: tt,
              type: type,
              currentVersion: currentVersions[type.dbKey] ?? '1.0.0',
              acceptedVersion: acceptedVersions[type.dbKey],
              onTap: () {
                final path = type == LegalDocumentType.termsOfService
                    ? '/legal/terms'
                    : '/legal/privacy';
                context.push(path);
              },
            ),
            if (type != LegalDocumentType.values.last)
              Divider(height: 1, color: c.border),
          ],
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({
    required this.c,
    required this.tt,
    required this.type,
    required this.currentVersion,
    required this.acceptedVersion,
    required this.onTap,
  });

  final JColors c;
  final TextTheme tt;
  final LegalDocumentType type;
  final String currentVersion;
  final String? acceptedVersion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accepted =
        acceptedVersion != null && acceptedVersion == currentVersion;

    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 4.h,
      ),
      leading: Icon(
        type == LegalDocumentType.termsOfService
            ? AppIcons.document
            : AppIcons.policy,
        color: c.text2,
        size: AppIconSize.md.r,
      ),
      title: Text(
        type.displayTitle,
        style: tt.bodyMedium!.copyWith(
          color: c.text1,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        accepted
            ? 'Version $currentVersion — Accepted'
            : 'Version $currentVersion${acceptedVersion != null ? ' — Update pending' : ''}',
        style: tt.labelSmall!.copyWith(color: accepted ? c.verified : c.text3),
      ),
      trailing: Icon(
        AppIcons.chevronRight,
        color: c.text3,
        size: AppIconSize.inline.r,
      ),
    );
  }
}
