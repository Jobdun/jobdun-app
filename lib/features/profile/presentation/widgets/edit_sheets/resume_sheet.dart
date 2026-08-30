import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../domain/entities/resume_rules.dart';
import '../../providers/profile_provider.dart';
import '../resume_row.dart';
import 'edit_sheet_scaffold.dart';

/// Opens the resume manager. Returns true when something changed.
Future<bool?> showResumeSheet(BuildContext context) =>
    showJSheet<bool>(context: context, builder: (_) => const ResumeSheet());

/// Upload / replace / remove an apprentice resume.
class ResumeSheet extends ConsumerStatefulWidget {
  const ResumeSheet({super.key});

  @override
  ConsumerState<ResumeSheet> createState() => _ResumeSheetState();
}

class _ResumeSheetState extends ConsumerState<ResumeSheet> {
  bool _busy = false;
  String? _error;
  bool _changed = false;

  Future<void> _pick() async {
    setState(() => _error = null);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kAllowedResumeExtensions,
      // Load-bearing on web: file_picker returns a NULL `path` there by design
      // and only ever guarantees `bytes` (manual_upload_sheet.dart:127 records
      // the same trap). Without this the admin/web build silently fails.
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final picked = result.files.first;
    final bytes = picked.bytes;
    if (bytes == null) {
      setState(() => _error = "Couldn't read that file. Try another.");
      return;
    }

    // Validate BEFORE uploading. Nobody should push 5 MB over site data to be
    // told the file was the wrong type.
    final problem = resumeFileProblem(picked.name, bytes.length);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() => _busy = true);
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .uploadResume(bytes, picked.name);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _changed = _changed || ok;
      _error = ok
          ? null
          : ref.read(profileControllerProvider).error ??
                "Couldn't upload. Try again.";
    });
  }

  Future<void> _remove() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .deleteResume();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _changed = _changed || ok;
      _error = ok
          ? null
          : ref.read(profileControllerProvider).error ??
                "Couldn't remove it. Try again.";
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final tp = ref.watch(
      profileControllerProvider.select((s) => s.tradeProfile),
    );

    return EditSheetScaffold(
      title: 'Resume',
      // Every action here writes immediately, so there is never an unsaved
      // edit to discard — SAVE just closes.
      isDirty: false,
      isSaving: false,
      error: _error,
      onSave: () => Navigator.of(context).pop(_changed),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Builders read this before they call. A page is plenty.',
            style: tt.bodyMedium!.copyWith(color: c.text2),
          ),
          Gap(AppSpacing.md.h),
          if (_busy) ...[
            LinearPercentIndicator(
              lineHeight: 6.h,
              percent: 1,
              animation: true,
              animationDuration: 900,
              barRadius: Radius.circular(AppRadius.badge.r),
              progressColor: c.action,
              backgroundColor: c.surfaceRaised,
              padding: EdgeInsets.zero,
            ),
            Gap(AppSpacing.md.h),
          ],
          if (tp?.hasResume ?? false)
            ResumeRow.owner(
              fileName: tp!.resumeFileName,
              uploadedAt: tp.resumeUploadedAt,
              onReplace: _busy ? () {} : _pick,
              onRemove: _busy ? () {} : _remove,
              isBusy: _busy,
            )
          else
            ResumeRow.empty(onUpload: _busy ? () {} : _pick),
          Gap(AppSpacing.sm.h),
        ],
      ),
    );
  }
}
