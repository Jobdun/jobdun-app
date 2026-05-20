import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';

/// Canonical Jobdun toggle switch — white thumb on bright-orange track when
/// active; muted slate when inactive.
///
/// Replaces the two ad-hoc treatments that diverged in the v1 codebase:
/// - `profile_page` used `c.action` thumb + `c.actionBg` track (muted amber)
/// - `job_create_page` used white thumb + `c.action` track (bright orange)
///
/// MASTER says "everything filled, orange-dominant". The bright orange wins —
/// more discoverable as an active control, matches the CTA rhythm.
class JSwitch extends StatelessWidget {
  const JSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white, // intentional: white-on-action
      activeTrackColor: c.action,
      inactiveThumbColor: c.text3,
      inactiveTrackColor: c.surfaceRaised,
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? c.action : c.border,
      ),
    );
  }
}
