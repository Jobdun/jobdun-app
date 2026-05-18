import 'package:flutter/widgets.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../auth/domain/entities/user_role.dart';

/// One bottom-nav slot: the icon pair (outline = inactive, Bold = active),
/// the short visible label, and a decoupled, fuller screen-reader label.
@immutable
class TabSpec {
  const TabSpec({
    required this.iconOutline,
    required this.iconFilled,
    required this.label,
    required this.semanticLabel,
  });

  /// Inactive glyph (Tabler outline variant).
  final IconData iconOutline;

  /// Active glyph (Tabler filled variant).
  final IconData iconFilled;

  /// Visible chip text — short, single word, iPhone-SE safe.
  final String label;

  /// Screen-reader text — decoupled from [label] so SR can be fuller/clearer
  /// while the visible chip stays short.
  final String semanticLabel;

  /// Trade-side tabs. Order MUST match the StatefulShellRoute branches in
  /// `lib/app/router/app_router.dart`: home, jobs, applications, messages,
  /// profile — the index is what `navigationShell.goBranch(i)` switches to.
  // `final`, not `const`: AppIcons nav entries are records, and record
  // field access (`.outline`/`.filled`) is not a constant expression.
  static final _trade = <TabSpec>[
    TabSpec(
      iconOutline: AppIcons.home.outline,
      iconFilled: AppIcons.home.filled,
      label: 'Home',
      semanticLabel: 'Home',
    ),
    TabSpec(
      iconOutline: AppIcons.findJobs.outline,
      iconFilled: AppIcons.findJobs.filled,
      label: 'Jobs',
      semanticLabel: 'Find work',
    ),
    TabSpec(
      iconOutline: AppIcons.applied.outline,
      iconFilled: AppIcons.applied.filled,
      label: 'Applied',
      semanticLabel: 'My applications',
    ),
    TabSpec(
      iconOutline: AppIcons.messages.outline,
      iconFilled: AppIcons.messages.filled,
      label: 'Messages',
      semanticLabel: 'Messages',
    ),
    TabSpec(
      iconOutline: AppIcons.profile.outline,
      iconFilled: AppIcons.profile.filled,
      label: 'Profile',
      semanticLabel: 'Profile',
    ),
  ];

  /// Tabs for [role]. Builder-side nav is a separate rollout; until then
  /// Builder reuses the same 5 slots so existing Builder navigation is
  /// unchanged (no regression). `null` (role not yet loaded) → same default.
  static List<TabSpec> forRole(UserRole? role) {
    // role is intentionally not branched yet — Builder tabs are a separate
    // rollout; the parameter is kept so call-sites are already correct.
    return _trade;
  }
}
