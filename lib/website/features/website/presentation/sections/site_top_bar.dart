import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/jobdun_logo.dart';
import '../providers/active_section_provider.dart';
import 'site_top_nav_link.dart';

/// Sticky top bar for the marketing site.
///
/// - Logo (left) → brand-mark + wordmark lockup, taps to scroll to top.
/// - Three scroll anchors (HOW IT WORKS / FOR HIRERS / FOR CREWS) — the
///   active one highlights as the user scrolls.
/// - GET THE APP (right) — filled orange CTA, surfaces the same onTap
///   passed in by `HomePage` (which scrolls to the closing CTA).
///
/// Crucially: this widget is `Positioned` *outside* the `CustomScrollView`,
/// so it must NEVER call `Scrollable.ensureVisible` directly — that would
/// throw "No scrollable widget found". Instead it routes scroll requests
/// through `scrollToProvider`, which `HomePage` consumes via the scroll
/// controller.
class SiteTopBar extends ConsumerWidget {
  const SiteTopBar({super.key, required this.onGetTheApp});

  final VoidCallback onGetTheApp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final active = ref.watch(activeSectionProvider);
    final scrolled = active != null;

    return Container(
      decoration: BoxDecoration(
        color: scrolled ? c.surface : c.background,
        border: Border(
          bottom: BorderSide(
            color: scrolled ? c.border : c.background,
            width: 1,
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: _hPad(context),
        vertical: AppSpacing.md.h,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            InkWell(
              onTap: () => ref.read(scrollToProvider.notifier).request('top'),
              child: const JobdunLogo(variant: LogoVariant.full),
            ),
            const Spacer(),
            // Nav — hidden on narrow phones, kept on tablet+. The new
            // page doesn't have 3 distinct sections worth nav-anchoring
            // (the screens/roles/bottom-cta all read as one continuous
            // flow), so we keep just one anchor: back to the top.
            if (MediaQuery.sizeOf(context).width >= 720) ...[
              SiteTopNavLink(
                label: 'ABOUT',
                active: false,
                onTap: () =>
                    ref.read(scrollToProvider.notifier).request('top'),
              ),
              Gap(AppSpacing.lg.w),
            ],
            _GetTheAppButton(onPressed: onGetTheApp),
          ],
        ),
      ),
    );
  }
}

double _hPad(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w >= 1100) return AppSpacing.xxl.w;
  if (w >= 720) return AppSpacing.xl.w;
  return AppSpacing.lg.w;
}

class _GetTheAppButton extends StatelessWidget {
  const _GetTheAppButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _CompactOrangeCta(label: 'GET THE APP', onPressed: onPressed);
  }
}

/// Compact orange CTA — used in the top bar so the bar height matches the
/// logo height (~32 logical px) instead of the standard 56dp JButton.
class _CompactOrangeCta extends StatelessWidget {
  const _CompactOrangeCta({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: c.action,
      borderRadius: BorderRadius.circular(AppRadius.btn.r),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          child: Text(
            label,
            style: tt.labelLarge!.copyWith(color: c.onAction),
          ),
        ),
      ),
    );
  }
}
