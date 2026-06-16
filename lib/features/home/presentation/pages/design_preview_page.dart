import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../app/theme/app_typography.dart';
import '../../../../app/theme/preview_theme.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_card.dart';
import '../../../../core/design/widgets/status_badge.dart';
import '../../../../core/widgets/inputs/j_text_field.dart';

/// Debug-only A/B surface for the **proposed design-token update** (2026-05-31):
/// the new ~1.2 type scale (40/32/26/22/18/16/14/12/11, explicit line-heights,
/// ratified tracking, tabular figures) + the denser 4/8/12/16/24/32/48 spacing
/// rhythm. Renders through [PreviewTheme.designV2Dark] and [PreviewSpace] so the
/// full setup can be eyeballed live **without** touching the global theme or the
/// 324 `AppSpacing` call sites. Reached from `/home` (kDebugMode only).
///
/// See `design-system/jobdun/MASTER.md` → Typography + Spacing.
class DesignPreviewPage extends StatelessWidget {
  const DesignPreviewPage({super.key});

  // (role sample, spec caption) — sizes/line-heights read live from the theme.
  static const _typeRoles = <(String, String)>[
    ('Display · 40', 'displayLarge · Archivo 800 · lh 1.06'),
    ('Headline L · 32', 'headlineLarge · Archivo 800 · lh 1.12'),
    ('Headline M · 26', 'headlineMedium · Archivo 700 · lh 1.18'),
    ('Headline S · 22', 'headlineSmall · Archivo 700 · lh 1.22'),
    ('Title L · 18', 'titleLarge · Archivo 700 · lh 1.25'),
    ('Title M · 16', 'titleMedium · Inter 600 · lh 1.50'),
    ('Body L · 16', 'bodyLarge · Inter 400 · lh 1.55'),
    ('Body M · 14', 'bodyMedium · Inter 400 · lh 1.55 · most-used'),
    ('Body S · 12', 'bodySmall · Inter 500 · +0.1 · floor'),
    ('LABEL L · 14', 'labelLarge · Archivo 800 · +0.8 · buttons CAPS'),
    ('Label M · 12', 'labelMedium · Inter 600 · +0.35 · chips'),
    ('Label S · 11', 'labelSmall · Inter 700 · +0.5 · eyebrows'),
  ];

  // (label, px) — the new spacing menu.
  static const _spaceTokens = <(String, double)>[
    ('xs', PreviewSpace.xs),
    ('sm', PreviewSpace.sm),
    ('md · NEW', PreviewSpace.md),
    ('lg', PreviewSpace.lg),
    ('xl', PreviewSpace.xl),
    ('2xl', PreviewSpace.xxl),
    ('3xl', PreviewSpace.xxxl),
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: PreviewTheme.designV2Dark(),
      child: Builder(
        builder: (context) {
          final c = context.c;
          final tt = Theme.of(context).textTheme;
          final note = tt.bodySmall!.copyWith(color: c.text3);

          // Live theme lookup by role so samples always reflect the real scale.
          final roleStyles = <TextStyle>[
            tt.displayLarge!,
            tt.headlineLarge!,
            tt.headlineMedium!,
            tt.headlineSmall!,
            tt.titleLarge!,
            tt.titleMedium!,
            tt.bodyLarge!,
            tt.bodyMedium!,
            tt.bodySmall!,
            tt.labelLarge!,
            tt.labelMedium!,
            tt.labelSmall!,
          ];

          return MediaQuery.withClampedTextScaling(
            minScaleFactor: 0.9,
            maxScaleFactor: 1.3,
            child: Scaffold(
              backgroundColor: c.background,
              appBar: AppBar(title: const Text('A/B · NEW TOKENS')),
              body: SafeArea(
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    PreviewSpace.xl.w,
                    PreviewSpace.lg.h,
                    PreviewSpace.xl.w,
                    PreviewSpace.xxl.h,
                  ),
                  children: [
                    Text(
                      'The full proposed token update, rendered live. Flip to /home '
                      'to compare against the shipping scale. Nothing here changes '
                      'the live app — global migration follows sign-off.',
                      style: tt.bodyMedium!.copyWith(color: c.text2),
                    ),
                    Gap(PreviewSpace.xxl.h),

                    // ── 1. Type scale ─────────────────────────────────────────
                    const FieldLabel('TYPE SCALE — 1.2 RATIO'),
                    Gap(PreviewSpace.md.h),
                    ...List.generate(_typeRoles.length, (i) {
                      final (sample, spec) = _typeRoles[i];
                      return Padding(
                        padding: EdgeInsets.only(bottom: PreviewSpace.md.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sample, style: roleStyles[i]),
                            Gap(PreviewSpace.xs.h),
                            Text(spec, style: note),
                          ],
                        ),
                      );
                    }),
                    Gap(PreviewSpace.sm.h),
                    Text(
                      'Distinct steps — the old 15/14/13 1-px cluster is gone. '
                      'Floors held at 12 (caption) / 11 (label).',
                      style: note,
                    ),
                    Gap(PreviewSpace.xxl.h),

                    // ── 2. Tabular figures ────────────────────────────────────
                    const FieldLabel('TABULAR FIGURES — PAY / COUNTS'),
                    Gap(PreviewSpace.md.h),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Proportional', style: note),
                              Gap(PreviewSpace.xs.h),
                              Text(r'$1,250.00', style: tt.titleLarge),
                              Text(r'$85.50', style: tt.titleLarge),
                              Text(r'$9.00', style: tt.titleLarge),
                            ],
                          ),
                        ),
                        Gap(PreviewSpace.lg.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Tabular · numeric()', style: note),
                              Gap(PreviewSpace.xs.h),
                              Text(
                                r'$1,250.00',
                                style: AppTypography.numeric(tt.titleLarge!),
                              ),
                              Text(
                                r'$85.50',
                                style: AppTypography.numeric(tt.titleLarge!),
                              ),
                              Text(
                                r'$9.00',
                                style: AppTypography.numeric(tt.titleLarge!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Gap(PreviewSpace.sm.h),
                    Text(
                      'Tabular digits share one advance width — rates align and '
                      'stop jittering as values change.',
                      style: note,
                    ),
                    Gap(PreviewSpace.xxl.h),

                    // ── 3. Spacing rhythm ─────────────────────────────────────
                    const FieldLabel('SPACING RHYTHM — 4/8/12/16/24/32/48'),
                    Gap(PreviewSpace.md.h),
                    ..._spaceTokens.map(
                      (t) => Padding(
                        padding: EdgeInsets.only(bottom: PreviewSpace.sm.h),
                        child: Row(
                          children: [
                            Container(
                              width: t.$2.w,
                              height: 14.h,
                              color: c.action,
                            ),
                            Gap(PreviewSpace.md.w),
                            Text(
                              '${t.$1} · ${t.$2.toInt()}',
                              style: tt.bodySmall!.copyWith(color: c.text2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Gap(PreviewSpace.sm.h),
                    Text(
                      'md=12 is new; lg 24→16 and xl 32→24 pull the workhorse '
                      'paddings one step tighter — denser, more aggressive.',
                      style: note,
                    ),
                    Gap(PreviewSpace.xxl.h),

                    // ── 4. Real components under the new scale ────────────────
                    const FieldLabel('COMPONENTS — NEW TYPE + SPACING'),
                    Gap(PreviewSpace.md.h),
                    Container(
                      height: 52.h,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.action,
                        borderRadius: BorderRadius.circular(AppRadius.btn.r),
                      ),
                      child: Text(
                        'APPLY NOW',
                        style: tt.labelLarge!.copyWith(color: c.onAction),
                      ),
                    ),
                    Gap(PreviewSpace.lg.h),
                    FormBuilder(
                      child: JTextField(
                        name: 'demo_email',
                        label: 'EMAIL',
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    Gap(PreviewSpace.lg.h),
                    JCard(
                      title: 'COMPANY DETAILS',
                      children: [
                        Padding(
                          padding: EdgeInsets.all(PreviewSpace.lg.w),
                          child: Text(
                            'Card inset is now lg=16 (was 24). Bordered chrome, '
                            'legible secondary copy at bodyMedium/14.',
                            style: tt.bodyMedium!.copyWith(color: c.text2),
                          ),
                        ),
                      ],
                    ),
                    Gap(PreviewSpace.md.h),
                    Wrap(
                      spacing: PreviewSpace.sm.w,
                      runSpacing: PreviewSpace.sm.h,
                      children: const [
                        StatusBadge(variant: BadgeVariant.verified),
                        StatusBadge(variant: BadgeVariant.available),
                        StatusBadge(variant: BadgeVariant.urgent),
                      ],
                    ),
                    Gap(PreviewSpace.xl.h),
                    Text(
                      'Radius stays sharp (4–8, MASTER §250) — no pills, no 16+ '
                      'corners. Fonts still load via google_fonts; bundling is a '
                      'separate tracked migration and is invisible here.',
                      style: note,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
