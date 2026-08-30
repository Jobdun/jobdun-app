import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';

enum _ResumeMode { empty, owner, viewer, locked }

/// The resume block, in one of four states.
///
/// A resume carries a home address, phone number, school and referees, and a
/// lot of apprentices are minors. The privacy line on the owner-facing states
/// is required copy, not decoration: someone uploading that document has to be
/// told who can read it BEFORE they tap, not after.
class ResumeRow extends StatelessWidget {
  /// No resume yet — the owner's upload prompt.
  const ResumeRow.empty({super.key, required VoidCallback onUpload})
    : _mode = _ResumeMode.empty,
      _onPrimary = onUpload,
      _onRemove = null,
      fileName = null,
      uploadedAt = null,
      isBusy = false;

  /// The owner's own resume: filename, date, replace and remove.
  const ResumeRow.owner({
    super.key,
    required this.fileName,
    required this.uploadedAt,
    required VoidCallback onReplace,
    required VoidCallback onRemove,
    this.isBusy = false,
  }) : _mode = _ResumeMode.owner,
       _onPrimary = onReplace,
       _onRemove = onRemove;

  /// A builder who has earned access — the apprentice applied to their job.
  const ResumeRow.viewer({super.key, required VoidCallback onView})
    : _mode = _ResumeMode.viewer,
      _onPrimary = onView,
      _onRemove = null,
      fileName = null,
      uploadedAt = null,
      isBusy = false;

  /// A builder with no relationship. Deliberately offers no way in, rather
  /// than a button that fails: the RLS policy would reject it anyway, and a
  /// dead button reads as a bug.
  const ResumeRow.locked({super.key})
    : _mode = _ResumeMode.locked,
      _onPrimary = null,
      _onRemove = null,
      fileName = null,
      uploadedAt = null,
      isBusy = false;

  final _ResumeMode _mode;
  final VoidCallback? _onPrimary;
  final VoidCallback? _onRemove;
  final String? fileName;
  final DateTime? uploadedAt;
  final bool isBusy;

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _fmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        switch (_mode) {
          _ResumeMode.locked => Text(
            'Resume available after they apply to one of your jobs.',
            style: tt.bodyMedium!.copyWith(color: c.text3),
          ),
          _ResumeMode.viewer => SizedBox(
            width: double.infinity,
            child: JButton(label: 'VIEW RESUME', onPressed: _onPrimary),
          ),
          _ResumeMode.empty => SizedBox(
            width: double.infinity,
            child: JButton(
              label: 'UPLOAD RESUME',
              isLoading: isBusy,
              onPressed: isBusy ? null : _onPrimary,
            ),
          ),
          _ResumeMode.owner => Container(
            padding: EdgeInsets.all(14.r),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AppRadius.card.r),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Icon(AppIcons.document, size: AppIconSize.md.r, color: c.text2),
                Gap(10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        fileName ?? 'Resume',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall!.copyWith(color: c.text1),
                      ),
                      if (uploadedAt != null) ...[
                        Gap(2.h),
                        Text(
                          'Uploaded ${_fmt(uploadedAt!)}',
                          style: tt.bodySmall!.copyWith(color: c.text3),
                        ),
                      ],
                    ],
                  ),
                ),
                Gap(8.w),
                _ResumeAction(label: 'REPLACE', onTap: _onPrimary),
                Gap(12.w),
                _ResumeAction(label: 'REMOVE', onTap: _onRemove, danger: true),
              ],
            ),
          ),
        },
        if (_mode == _ResumeMode.empty || _mode == _ResumeMode.owner) ...[
          Gap(AppSpacing.sm.h),
          Text(
            "Only builders you've applied to can open this.",
            style: tt.bodySmall!.copyWith(color: c.text2),
          ),
        ],
      ],
    );
  }
}

class _ResumeAction extends StatelessWidget {
  const _ResumeAction({
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          // 48 unscaled: the WCAG 2.5.5 floor is absolute logical pixels.
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            child: Text(
              label,
              style: tt.labelSmall!.copyWith(
                color: danger ? c.urgent : c.actionInk,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
