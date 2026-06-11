import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/j_button.dart';
import 'discard_changes_sheet.dart';

/// Shared chrome for the quick-edit profile sheets: header (all-caps title +
/// ✕), scrollable body that rides above the keyboard, inline error line, and
/// the all-caps SAVE button.
///
/// Dirty dismissal (drag-down, barrier tap, ✕, system back) is intercepted
/// via a scoped willPop callback → discard confirm. Two traps, both verified
/// by rates_sheet_test:
///  1. WillPopScope (not PopScope) is load-bearing: modal_bottom_sheet's
///     drag-to-dismiss only consults the route's scoped willPop callbacks
///     (`shouldClose` in its bottom_sheet_route.dart) and otherwise calls
///     Navigator.pop() directly, bypassing PopScope — a dirty sheet would
///     discard edits silently on drag.
///  2. The callback must be registered from the FIRST build (not only once
///     dirty): the package snapshots `shouldClose` when the sheet route
///     builds, so a late registration leaves the drag handler holding null.
///     The always-registered callback checks `isDirty` in its body instead.
class EditSheetScaffold extends StatelessWidget {
  const EditSheetScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.onSave,
    required this.isSaving,
    required this.isDirty,
    this.error,
  });

  final String title;
  final Widget body;
  final VoidCallback onSave;
  final bool isSaving;
  final bool isDirty;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // ignore: deprecated_member_use — see class doc: the modal package's
    // drag veto only works through scoped willPop callbacks.
    return WillPopScope(
      onWillPop: () async {
        if (!isDirty) return true;
        return showDiscardChangesSheet(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 14.h, 8.w, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.toUpperCase(),
                        style: tt.titleMedium!.copyWith(
                          color: c.text1,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Close',
                      icon: Icon(
                        AppIcons.close,
                        size: AppIconSize.md.r,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                  child: body,
                ),
              ),
              if (error != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 0),
                  child: Text(
                    error!,
                    style: tt.bodySmall!.copyWith(color: c.urgent),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
                child: SizedBox(
                  width: double.infinity,
                  child: JButton(
                    label: 'SAVE',
                    isLoading: isSaving,
                    onPressed: isSaving ? null : onSave,
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
