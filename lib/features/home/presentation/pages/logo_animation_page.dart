import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/animated_jobdun_logo.dart';
import '../../../../core/design/widgets/j_button.dart';

/// Dev-only showcase (kDebugMode route `/logo-animation`) for the hammer-J
/// "creation" animation. Plays the [AnimatedJobdunLogo] variants with a replay
/// control + a variant switcher, and documents the top-5 animation use-cases
/// for the login/FTUE surfaces.
class LogoAnimationPage extends StatefulWidget {
  const LogoAnimationPage({super.key});

  @override
  State<LogoAnimationPage> createState() => _LogoAnimationPageState();
}

class _LogoAnimationPageState extends State<LogoAnimationPage> {
  JLogoAnim _variant = JLogoAnim.forge;
  // Changing this key rebuilds the stage's AnimatedJobdunLogo from scratch,
  // which restarts the animation (replay / variant-switch).
  Key _stageKey = UniqueKey();

  void _select(JLogoAnim v) => setState(() {
    _variant = v;
    _stageKey = UniqueKey();
  });

  void _replay() => setState(() => _stageKey = UniqueKey());

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(AppIcons.back, color: c.text1, size: AppIconSize.md.r),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
        title: Text(
          'LOGO ANIMATION',
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(AppSpacing.lg.h),

              // ── Stage ──────────────────────────────────────────────────────
              Container(
                height: 240.h,
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.card.r),
                  border: Border.all(color: c.border),
                ),
                alignment: Alignment.center,
                child: AnimatedJobdunLogo(
                  key: _stageKey,
                  variant: _variant,
                  height: 156.r,
                ),
              ),
              Gap(AppSpacing.md.h),

              // ── Variant switcher ──────────────────────────────────────────
              Row(
                children: [
                  for (final v in JLogoAnim.values) ...[
                    Expanded(
                      child: _VariantChip(
                        label: _labelFor(v),
                        selected: _variant == v,
                        onTap: () => _select(v),
                      ),
                    ),
                    if (v != JLogoAnim.values.last) Gap(8.w),
                  ],
                ],
              ),
              Gap(AppSpacing.sm.h),
              JButton(
                label: 'REPLAY',
                variant: JButtonVariant.primary,
                size: JButtonSize.compact,
                onPressed: _replay,
              ),
              Gap(6.h),
              Text(
                _blurbFor(_variant),
                textAlign: TextAlign.center,
                style: tt.bodySmall!.copyWith(color: c.text3),
              ),

              Gap(AppSpacing.xl.h),

              // ── Use cases ─────────────────────────────────────────────────
              Text(
                'TOP 5 ANIMATION USE-CASES',
                style: tt.labelSmall!.copyWith(
                  color: c.text2,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Gap(AppSpacing.sm.h),
              ..._useCases.map((u) => _UseCaseCard(data: u)),

              Gap(AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }

  static String _labelFor(JLogoAnim v) => switch (v) {
    JLogoAnim.forge => 'FORGE',
    JLogoAnim.strike => 'STRIKE',
    JLogoAnim.draw => 'DRAW',
  };

  static String _blurbFor(JLogoAnim v) => switch (v) {
    JLogoAnim.forge =>
      'Scale-in + shimmer sweep + spark. Theme-aware — ships to splash + login.',
    JLogoAnim.strike => 'Drops in with an overshoot bounce + an impact spark.',
    JLogoAnim.draw =>
      'The vector outline draws itself (PathMetrics), then the fill arrives.',
  };
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? c.actionBg : c.surface,
          borderRadius: BorderRadius.circular(AppRadius.btn.r),
          border: Border.all(color: selected ? c.action : c.border),
        ),
        child: Text(
          label,
          style: tt.labelSmall!.copyWith(
            color: selected ? c.actionInk : c.text2,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

// ── Use-case data ──────────────────────────────────────────────────────────────

enum _UseStatus { built, scaffold, planned }

class _UseCase {
  const _UseCase({
    required this.title,
    required this.where,
    required this.why,
    required this.technique,
    required this.status,
  });

  final String title;
  final String where;
  final String why;
  final String technique;
  final _UseStatus status;
}

const _useCases = <_UseCase>[
  _UseCase(
    title: 'Splash forge',
    where: 'Splash (app open)',
    why: 'First brand moment — the mark forges in instead of popping static.',
    technique: 'AnimatedJobdunLogo · forge',
    status: _UseStatus.built,
  ),
  _UseCase(
    title: 'Login hero',
    where: 'Login hero zone',
    why: 'A subtle one-shot greets returning users without slowing them down.',
    technique: 'AnimatedJobdunLogo · forge',
    status: _UseStatus.built,
  ),
  _UseCase(
    title: 'Empty-state spots',
    where: 'Jobs · Applications · Messages · Reviews',
    why: 'Replace flat icons with a friendly looping illustration + CTA.',
    technique: 'Lottie in EmptyState widget (needs .json)',
    status: _UseStatus.scaffold,
  ),
  _UseCase(
    title: 'Verify-email',
    where: 'Verify-email icon zone',
    why: 'Envelope opens → checkmark on confirm; reassures during the wait.',
    technique: 'Lottie one-shot (needs .json)',
    status: _UseStatus.scaffold,
  ),
  _UseCase(
    title: 'FTUE map pulse',
    where: 'FTUE slide 2 (jobs near you)',
    why: 'Pulsing pin-hammer + radar rings sell the "jobs around you" idea.',
    technique: 'CustomPainter (extend ftue_map_hero)',
    status: _UseStatus.planned,
  ),
];

class _UseCaseCard extends StatelessWidget {
  const _UseCaseCard({required this.data});

  final _UseCase data;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final (badgeText, badgeColor) = switch (data.status) {
      _UseStatus.built => ('BUILT', c.verified),
      _UseStatus.scaffold => ('NEEDS .JSON', c.warning),
      _UseStatus.planned => ('PLANNED', c.text3),
    };

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  data.title,
                  style: tt.titleSmall!.copyWith(
                    color: c.text1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.chip.r),
                ),
                child: Text(
                  badgeText,
                  style: tt.labelSmall!.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          Gap(4.h),
          Text(data.where, style: tt.bodySmall!.copyWith(color: c.actionInk)),
          Gap(6.h),
          Text(
            data.why,
            style: tt.bodySmall!.copyWith(color: c.text2, height: 1.4),
          ),
          Gap(6.h),
          Text(data.technique, style: tt.labelSmall!.copyWith(color: c.text3)),
        ],
      ),
    );
  }
}
