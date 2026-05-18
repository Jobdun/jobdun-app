import 'package:flutter/widgets.dart';
import 'package:iconsax/iconsax.dart';

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

  /// Inactive glyph (Iconsax outline variant).
  final IconData iconOutline;

  /// Active glyph (Iconsax Bold/filled variant).
  final IconData iconFilled;

  /// Visible chip text — short, single word, iPhone-SE safe.
  final String label;

  /// Screen-reader text — decoupled from [label] so SR can be fuller/clearer
  /// while the visible chip stays short.
  final String semanticLabel;

  /// Trade-side tabs. Order MUST match the StatefulShellRoute branches in
  /// `lib/app/router/app_router.dart`: home, jobs, applications, messages,
  /// profile — the index is what `navigationShell.goBranch(i)` switches to.
  static const _trade = <TabSpec>[
    TabSpec(
      iconOutline: Iconsax.home_2,
      iconFilled: Iconsax.home_25,
      label: 'Home',
      semanticLabel: 'Home',
    ),
    TabSpec(
      iconOutline: Iconsax.briefcase,
      iconFilled: Iconsax.briefcase5,
      label: 'Jobs',
      semanticLabel: 'Find work',
    ),
    TabSpec(
      iconOutline: Iconsax.document_text,
      iconFilled: Iconsax.document_text1,
      label: 'Applied',
      semanticLabel: 'My applications',
    ),
    TabSpec(
      iconOutline: Iconsax.message,
      iconFilled: Iconsax.message5,
      label: 'Messages',
      semanticLabel: 'Messages',
    ),
    TabSpec(
      iconOutline: Iconsax.user,
      iconFilled: Iconsax.user5,
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
