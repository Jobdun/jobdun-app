part of 'profile_page.dart';

// Settings section, the shared info/action/toggle rows, and the value-format
// helpers, split into a `part` so `profile_page.dart` stays under the file-size
// budget. Used by the profile sections in profile_page_sections.dart — same
// library, so the cross-part references resolve. No behaviour change.

// ── Settings ───────────────────────────────────────────────────────────────────

class _SettingsSection extends ConsumerWidget {
  const _SettingsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        children: [
          JCard(
            title: 'APPEARANCE',
            children: [
              _ToggleRow(
                icon: isDark ? AppIcons.moon : AppIcons.sun,
                label: 'Dark mode',
                value: isDark,
                onChanged: (_) => ref.read(themeProvider.notifier).toggle(),
              ),
            ],
          ),
          Gap(12.h),
          JCard(
            title: 'ACCOUNT',
            children: [
              _ActionRow(icon: AppIcons.email, label: 'Change email'),
              _ActionRow(icon: AppIcons.lock, label: 'Change password'),
              _ActionRow(icon: AppIcons.notification, label: 'Notifications'),
              _ActionRow(icon: AppIcons.policy, label: 'Privacy settings'),
            ],
          ),
          Gap(12.h),
          JCard(
            title: 'LEGAL',
            children: [
              _ActionRow(
                icon: AppIcons.document,
                label: 'Terms of Service',
                onTap: () => context.push('/legal/terms'),
              ),
              _ActionRow(
                icon: AppIcons.shield,
                label: 'Privacy Policy',
                onTap: () => context.push('/legal/privacy'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Dev-only quick-links to the preview/showcase screens. Relocated here off the
// home feed (was the in-feed `_DebugToolsBar`) so the live home layout reads
// clean while developing. Instantiated only behind `if (kDebugMode)` in
// profile_page.dart, so it's stripped from release builds.
class _DevToolsCard extends StatelessWidget {
  const _DevToolsCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: JCard(
        title: 'DEVELOPER TOOLS',
        children: [
          _ActionRow(
            icon: AppIcons.eyeOpen,
            label: 'Home preview (fixed tokens)',
            onTap: () => context.push('/home-preview'),
          ),
          _ActionRow(
            icon: AppIcons.gridView,
            label: 'Design tokens',
            onTap: () => context.push('/design-preview'),
          ),
          _ActionRow(
            icon: AppIcons.image,
            label: 'Logo animation',
            onTap: () => context.push('/logo-animation'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.verified = false,
  });

  final IconData icon;
  final String label;

  /// Null or blank renders a muted "Not set" — never a fabricated value.
  final String? value;

  /// When set, the row becomes tappable (e.g. website → launchUrl). Only
  /// fires when [value] is non-blank — "Not set" rows aren't actionable.
  final VoidCallback? onTap;

  /// When true, a small green seal-check renders to the right of the value.
  /// Used today to confirm a builder's ABN has been matched against the
  /// Australian Business Register — the full receipt still lives in the
  /// VerificationReceipts panel below, this is just an inline confirmation.
  final bool verified;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    final hasValue = value != null && value!.trim().isNotEmpty;
    // Three tap modes:
    //   • value present + onTap set → action on the value (e.g. open website)
    //   • value missing + onTap set → "Add" affordance routing to edit page
    //   • no onTap → static row
    final tappable = onTap != null;
    final isAddCta = !hasValue && tappable;
    final showTick = verified && hasValue;

    final valueColor = isAddCta
        ? c.action
        : hasValue
        ? (tappable ? c.action : c.text1)
        : c.text3;

    final row = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 12.h,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: AppIconSize.inline.r, color: c.text3),
          Gap(12.w),
          Text(label, style: tt.bodyMedium!.copyWith(color: c.text2)),
          Gap(12.w),
          Expanded(
            child: Text(
              hasValue ? value! : (isAddCta ? 'Add' : 'Not set'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: tt.bodyMedium!.copyWith(
                fontWeight: hasValue
                    ? FontWeight.w600
                    : (isAddCta ? FontWeight.w600 : FontWeight.w400),
                color: valueColor,
              ),
            ),
          ),
          if (showTick) ...[
            Gap(8.w),
            Tooltip(
              message: verified && label == 'Phone'
                  ? 'Phone number verified via SMS'
                  : 'Checked against the Australian Business Register',
              child: Icon(
                AppIcons.verified,
                size: AppIconSize.inline.r,
                color: c.verified,
              ),
            ),
          ],
          if (isAddCta) ...[
            Gap(6.w),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.inline.r,
              color: c.action,
            ),
          ],
        ],
      ),
    );
    if (!tappable) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

/// `WA` + `6061` → `WA 6061`. Either or both can be null — return null only
/// when nothing is set so the row hides entirely.
String? _formatRegisteredLocation(String? state, String? postcode) {
  final hasState = state != null && state.trim().isNotEmpty;
  final hasPostcode = postcode != null && postcode.trim().isNotEmpty;
  if (!hasState && !hasPostcode) return null;
  if (hasState && hasPostcode) return '${state.trim()} ${postcode.trim()}';
  return (state ?? postcode)!.trim();
}

/// `2013-08-12` → `Aug 2013`. Returns null for null input so the row hides.
/// Day precision is irrelevant to the human reading "in business since" —
/// month + year is the trust signal.
String? _formatInBusinessSince(DateTime? d) {
  if (d == null) return null;
  const months = [
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
  return '${months[d.month - 1]} ${d.year}';
}

/// `93779861687` → `93 779 861 687`. Returns null for null/blank input. Spaces
/// after the leading 2 digits + every following triplet match ABR's display
/// convention and read significantly faster on small screens.
String? _formatAbn(String? raw) {
  if (raw == null) return null;
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.length != 11) return raw; // unexpected — return as-is
  return '${digits.substring(0, 2)} '
      '${digits.substring(2, 5)} '
      '${digits.substring(5, 8)} '
      '${digits.substring(8, 11)}';
}

/// `+639917934774` → `+63 991 793 4774`. Falls back to the raw string if the
/// number isn't long enough to chunk cleanly — we never want to mangle a
/// number the user is reading off a screen to copy-confirm.
String? _formatPhone(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  // Tolerate stored-without-`+` values like the one set by Supabase Auth.
  var s = raw.trim();
  if (!s.startsWith('+')) s = '+$s';
  final digits = s.substring(1).replaceAll(RegExp(r'\D'), '');
  if (digits.length < 8) return s;
  // Heuristic split: 2-digit country code, then 3-3-rest.
  final cc = digits.substring(0, 2);
  final rest = digits.substring(2);
  if (rest.length <= 6) return '+$cc $rest';
  final a = rest.substring(0, 3);
  final b = rest.substring(3, 6);
  final tail = rest.substring(6);
  return '+$cc $a $b $tail';
}

/// Returns null for null/blank strings so [_InfoRow] shows its empty state
/// instead of an empty or fabricated value.
String? _blank(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();

/// Launches the builder's website in an in-app browser. Auto-prepends https://
/// if the user saved a bare domain (we don't enforce a scheme at write time).
Future<void> _launchWebsite(String raw) async {
  final url = raw.startsWith('http') ? raw : 'https://$raw';
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
  }
}

/// Formats the tradie hourly-rate range for the TRADE DETAILS card.
/// - Visibility off → "Rate on request" (still shows the row).
/// - Both null/zero → null (row hides via _InfoRow's empty state).
/// - Min only → "$X+/hr"; max only → "Up to $X/hr"; both → "$X–Y/hr".
String? _formatHourlyRate(TradeProfile? p) {
  if (p == null) return null;
  if (!p.hourlyRateVisible) return 'Rate on request';
  final min = p.hourlyRateMin;
  final max = p.hourlyRateMax;
  if (min == null && max == null) return null;
  String fmt(double v) => '\$${v.toStringAsFixed(0)}';
  if (min != null && max != null) return '${fmt(min)}–${fmt(max)}/hr';
  if (min != null) return '${fmt(min)}+/hr';
  return 'Up to ${fmt(max!)}/hr';
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () {},
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w,
          vertical: 14.h,
        ),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: c.text2),
            Gap(12.w),
            Expanded(
              child: Text(
                label,
                style: tt.bodyLarge!.copyWith(
                  fontWeight: FontWeight.w500,
                  color: c.text1,
                ),
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              size: AppIconSize.inline.r,
              color: c.text3,
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: 10.h,
      ),
      child: Row(
        children: [
          Icon(icon, size: AppIconSize.md.r, color: c.text2),
          Gap(12.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyLarge!.copyWith(
                fontWeight: FontWeight.w500,
                color: c.text1,
              ),
            ),
          ),
          JSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
