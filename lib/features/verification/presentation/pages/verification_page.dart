import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../../../core/services/image_upload_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

// Minimum viable licence-upload surface. Only trades land here from the
// VERIFICATION row on /profile/edit. Builders shouldn't normally see this
// — the route stays gated by trade role inside the page so a deep-link
// from a wrong-role user gets a friendly bounce.
//
// What it does today:
//   1. Picks an image of the licence card from gallery or camera.
//   2. Uploads to private-docs bucket via ProfileController.uploadTradeLicence.
//   3. Inserts a verification_documents row (status = 'pending') for the
//      future admin review queue.
//   4. Pops back to /profile/edit; the banner re-reads completeness.
//
// Out of scope for this PR: PDF picking, multi-page docs, status pipeline
// (reviewing → approved → rejected), licence-expiry tracking. Those land
// when the moderation queue ships in audit T4.
class VerificationPage extends ConsumerStatefulWidget {
  const VerificationPage({super.key});

  @override
  ConsumerState<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends ConsumerState<VerificationPage> {
  Future<void> _pick(BuildContext context, ImageSource source) async {
    // Licence cards / certs come in many sizes (NSW White Card, QBCC,
    // electrical licence) — free aspect, slightly higher JPEG quality
    // than the portfolio pipeline so the small print stays legible after
    // compression.
    final file = await ImageUploadService.pickCropCompress(
      source: source,
      aspect: ImageAspect.free,
      compressQuality: 88,
      minOutputWidth: 1440,
    );
    if (file == null || !context.mounted) return;
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .uploadTradeLicence(file);

    if (!context.mounted) return;
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final messenger = ScaffoldMessenger.of(context);
    if (ok) {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: c.verified,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'Licence uploaded — pending review.',
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-success
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      if (context.canPop()) context.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: c.urgent,
          behavior: SnackBarBehavior.floating,
          content: Text(
            "Couldn't upload. Try again.",
            style: tt.bodyMedium!.copyWith(
              color: Colors.white, // intentional: white-on-error
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final auth = ref.watch(authControllerProvider);
    final tp = ref.watch(
      profileControllerProvider.select((s) => s.tradeProfile),
    );
    final isUploading = ref.watch(
      profileControllerProvider.select((s) => s.isUploadingLicence),
    );

    // Builder hit this route somehow — bounce them back. RLS would block
    // their upload anyway but the screen makes no sense for their role.
    if (auth.role == UserRole.builder) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && context.canPop()) context.pop();
      });
      return Scaffold(backgroundColor: c.background);
    }

    final hasLicence = tp?.hasLicence ?? false;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        leading: IconButton(
          icon: Icon(AppIcons.back, color: c.text1),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/profile'),
        ),
        title: const FieldLabel('VERIFICATION'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(AppSpacing.md.h),
              const PageHeader(
                eyebrow: 'TRADE LICENCE',
                title: 'Licence on file',
                size: PageHeaderSize.tab,
              ),
              Gap(AppSpacing.sm.h),
              Text(
                'Upload a clear photo of the front of your licence card. '
                "We'll review and mark you verified within 1 business day.",
                style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.45),
              ),
              Gap(AppSpacing.xl.h),
              _StatusCard(hasLicence: hasLicence),
              Gap(AppSpacing.xl.h),
              JButton(
                label: hasLicence ? 'REPLACE PHOTO' : 'TAKE A PHOTO',
                icon: AppIcons.camera,
                isLoading: isUploading,
                onPressed: isUploading
                    ? null
                    : () => _pick(context, ImageSource.camera),
              ),
              Gap(AppSpacing.md.h),
              JButton(
                label: 'CHOOSE FROM GALLERY',
                variant: JButtonVariant.secondary,
                isLoading: false,
                onPressed: isUploading
                    ? null
                    : () => _pick(context, ImageSource.gallery),
              ),
              const Spacer(),
              Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
                child: Text(
                  "Stored privately. Only you and Jobdun's verifier see the "
                  'file. Builders only see a "verified" badge.',
                  textAlign: TextAlign.center,
                  style: tt.bodySmall!.copyWith(
                    color: c.text3,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.hasLicence});

  final bool hasLicence;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final tone = hasLicence ? c.verified : c.text3;
    final iconBg = hasLicence ? c.verifiedBg : c.surface;
    final title = hasLicence ? 'LICENCE ON FILE' : 'NO LICENCE YET';
    final body = hasLicence
        ? 'Pending review. Re-upload if you need to update.'
        : 'Builders see "verified" once we approve your upload.';

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.r),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40.r,
            height: 40.r,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(AppRadius.avatar.r),
            ),
            child: Icon(
              hasLicence ? AppIcons.policy : AppIcons.document,
              size: 20.r,
              color: tone,
            ),
          ),
          Gap(AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.labelSmall!.copyWith(
                    letterSpacing: 1.32,
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Gap(2.h),
                Text(body, style: tt.bodySmall!.copyWith(color: c.text2)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
