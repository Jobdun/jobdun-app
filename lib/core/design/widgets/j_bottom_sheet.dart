import 'package:flutter/material.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

/// Jobdun-flavoured bottom sheet helper.
///
/// Wraps [showMaterialModalBottomSheet] so every modal across the app shares
/// the same iOS-native drag-to-dismiss + spring physics + brand barrier
/// colour. Callers keep ownership of the inner chrome (background fill,
/// rounded corners, drag handle) because most sheets in this codebase
/// already decorate their own surface — the helper just standardises the
/// presentation/dismiss behaviour around them.
///
/// Why over `showModalBottomSheet`. Flutter's built-in modal lacks the
/// iOS drag-to-dismiss physics and uses stock Material easing. Mixing both
/// across screens produced visible inconsistency (one sheet bounces back
/// on partial drag, another snaps). This wrapper is the single point of
/// presentation; feature code must never call `showModalBottomSheet`
/// directly.
Future<T?> showJSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,

  /// True when the sheet should fill the screen (apply form, full-screen
  /// pickers). Defaults to false — sheet sizes to its content.
  bool expand = false,

  /// Tap outside dismisses. Set false for gated decisions (role pick,
  /// terms acceptance) where the user must engage.
  bool isDismissible = true,

  /// Drag-down dismisses. Set false for the same gated-decision flows.
  bool enableDrag = true,

  /// Background painted under the sheet content. Defaults to transparent
  /// so callers that decorate their own card surface keep working
  /// unchanged. Pass `context.c.card` when you want the helper to paint
  /// the brand surface for you.
  Color? backgroundColor,

  /// Optional outer shape (corner clipping). Default null — the inner
  /// widget owns its corner radii.
  ShapeBorder? shape,
}) {
  return showMaterialModalBottomSheet<T>(
    context: context,
    backgroundColor: backgroundColor ?? Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    shape: shape,
    expand: expand,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    builder: builder,
  );
}
