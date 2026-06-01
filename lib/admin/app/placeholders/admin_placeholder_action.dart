import 'package:flutter/material.dart';

import '../../../core/design/widgets/j_button.dart';
import '../../../core/theme/app_icons.dart';

/// A disabled moderation/billing button that announces *when* it wires up.
///
/// Renders a [JButton] with `onPressed: null` (JButton already paints the
/// reduced-alpha disabled state) plus a lock glyph, wrapped in a [Tooltip] so
/// hovering states the phase. Used for the Phase-2 Suspend/Ban (user) and
/// Hide/Remove (job) actions so all four look and behave identically.
class AdminPlaceholderAction extends StatelessWidget {
  const AdminPlaceholderAction({
    super.key,
    required this.label,
    required this.tooltip,
    this.variant = JButtonVariant.secondary,
  });

  /// Already-uppercased action label, e.g. 'SUSPEND', 'BAN'.
  final String label;

  /// Hover copy stating the wiring phase, e.g. 'Wiring in Phase 2 — moderation'.
  final String tooltip;

  /// [JButtonVariant.secondary] for the softer action (Suspend / Hide),
  /// [JButtonVariant.danger] for the destructive one (Ban / Remove).
  final JButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: JButton(
        label: label,
        variant: variant,
        size: JButtonSize.compact,
        icon: AppIcons.lock,
        onPressed: null,
      ),
    );
  }
}
