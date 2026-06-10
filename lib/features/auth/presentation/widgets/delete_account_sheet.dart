import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/theme/app_icons.dart';
import '../providers/auth_provider.dart';

/// Play-policy account deletion confirm. Deliberately heavier than the
/// logout confirm: states what is destroyed, requires the explicit danger
/// CTA, and surfaces failure as a contact-support line (a RESTRICT FK aborts
/// the whole server-side transaction — nothing half-deletes).
Future<void> showDeleteAccountSheet(BuildContext context, WidgetRef ref) {
  return showJSheet<void>(
    context: context,
    expand: false,
    isDismissible: false,
    backgroundColor: context.c.background,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _DeleteAccountSheetBody(),
  );
}

class _DeleteAccountSheetBody extends ConsumerStatefulWidget {
  const _DeleteAccountSheetBody();

  @override
  ConsumerState<_DeleteAccountSheetBody> createState() =>
      _DeleteAccountSheetBodyState();
}

class _DeleteAccountSheetBodyState
    extends ConsumerState<_DeleteAccountSheetBody> {
  bool _deleting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).deleteAccount();
      // Router redirect handles navigation once auth state clears; just
      // close the sheet if we're still mounted.
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error =
            "Couldn't delete your account. Try again in a minute — if it "
            'keeps failing, contact support@jobdun.com.au and we will '
            'delete it for you.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.warning, size: AppIconSize.feature.r, color: c.urgent),
            Gap(12.h),
            Text(
              'Delete your account?',
              style: tt.headlineSmall!.copyWith(fontWeight: FontWeight.w700),
            ),
            Gap(8.h),
            Text(
              'This permanently removes your profile, jobs, applications, '
              'messages, and verification documents. There is no undo.',
              style: tt.bodyMedium,
            ),
            if (_error != null) ...[
              Gap(12.h),
              Text(_error!, style: tt.bodySmall!.copyWith(color: c.urgent)),
            ],
            Gap(20.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: _deleting ? 'DELETING…' : 'DELETE MY ACCOUNT',
                variant: JButtonVariant.danger,
                onPressed: _deleting ? null : _confirm,
              ),
            ),
            Gap(8.h),
            SizedBox(
              width: double.infinity,
              child: JButton(
                label: 'KEEP MY ACCOUNT',
                variant: JButtonVariant.secondary,
                onPressed: _deleting
                    ? null
                    : () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
