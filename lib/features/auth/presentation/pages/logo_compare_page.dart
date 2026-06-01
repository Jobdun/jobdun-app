import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';

class LogoComparePage extends StatelessWidget {
  const LogoComparePage({super.key});

  static const _hammerFamily = <_Concept>[
    _Concept(
      name: 'HAMMER ABOVE J',
      stage: 'STACKED · TWO ELEMENTS',
      tagline: 'Tool on top. Letter below.',
      markPath: 'lib/core/assets/logo-concepts/hammer-j-above/mark.svg',
      lockupPath: 'lib/core/assets/logo-concepts/hammer-j-above/lockup.svg',
      story:
          'A complete hammer (orange head + claw V + handle stub) sits '
          'directly above a complete J letterform (top crossbar + stem '
          '+ curl). Both elements fully formed, fully readable. The '
          'tool and the letter are unmistakable — no design knowledge '
          'required to read it.',
      sells: 'CLARITY · TWO-PART · UNMISTAKABLE',
      precedent: 'Two-icon stacking: Texaco star + T, Shell shell + name.',
    ),
    _Concept(
      name: 'HAMMER FUSED J',
      stage: 'INTEGRATED · ONE SHAPE',
      tagline: 'Where tool becomes letter.',
      markPath: 'lib/core/assets/logo-concepts/hammer-j-fused/mark.svg',
      lockupPath: 'lib/core/assets/logo-concepts/hammer-j-fused/lockup.svg',
      story:
          'The hammer\'s handle IS the J\'s stem. The orange head sits '
          'on top with a claw V on the right. Below the hammer\'s '
          'handle, a white curl extends left — the J\'s signature. One '
          'continuous form. Orange = hammer, white curl = J identity.',
      sells: 'INTEGRATED · DESIGNERLY · ICONIC',
      precedent: 'Letter-as-tool school: Apple bite, Beats lowercase b.',
    ),
    _Concept(
      name: 'HAMMER + J',
      stage: 'PAIRED · SIDE BY SIDE',
      tagline: 'The tool and its job.',
      markPath: 'lib/core/assets/logo-concepts/hammer-j-side/mark.svg',
      lockupPath: 'lib/core/assets/logo-concepts/hammer-j-side/lockup.svg',
      story:
          'A vertical hammer icon on the left (head + claw V + long '
          'handle) paired with a full J letterform on the right. Like '
          'two adjacent stamps on a worksite sign. Both elements get '
          'equal weight — the hammer is not subordinate to the letter.',
      sells: 'BALANCED · DUAL · TRADIE-STAMP',
      precedent: 'Paired marks: Marvel name + icon, NBA logo + name.',
    ),
    _Concept(
      name: 'HAMMERHEAD J',
      stage: 'OFFSET · CROSSBAR-AS-HEAD',
      tagline: 'The head crowns the J.',
      markPath: 'lib/core/assets/logo-concepts/hammer-j-head/mark.svg',
      lockupPath: 'lib/core/assets/logo-concepts/hammer-j-head/lockup.svg',
      story:
          'The J\'s top crossbar is replaced by an asymmetric hammer '
          'head — extending mostly to the LEFT of the stem with a clear '
          'claw V on the right. The asymmetry is what makes it read as '
          'a hammer, not just a wide top. Most compact of the four.',
      sells: 'COMPACT · ASYMMETRIC · CLAW-FORWARD',
      precedent: 'Letter modification school: Adidas mountain stripes.',
    ),
  ];

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
          icon: Icon(
            AppIcons.arrowLeft,
            color: c.text1,
            size: AppIconSize.md.r,
          ),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/login'),
        ),
        title: Text(
          'HAMMER-J CONCEPTS',
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Gap(AppSpacing.md.h),
              Text(
                'PICK THE WINNER',
                style: tt.displaySmall!.copyWith(
                  color: c.text1,
                  fontSize: 30,
                  letterSpacing: 2.0,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Gap(8.h),
              Text(
                'Per client brief: minimal industrial tradie identity. '
                'Geometric J + symbolic hammer + orange completion '
                'accent. Four variants spanning literal → abstract. All '
                'pass the favicon / hard-hat / no-clipart tests.',
                style: tt.bodyMedium!.copyWith(
                  color: c.text2,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              Gap(AppSpacing.lg.h),
              _SectionHeader(
                label: 'HAMMER-J FAMILY',
                description:
                    'One direction, four executions. From most literal '
                    '(claw hammer integrated into J) to most abstract '
                    '(implied hammer via impact zone only). All built '
                    'to the brief: minimal, geometric, industrial, '
                    'memorable, scalable.',
              ),
              Gap(AppSpacing.md.h),
              ..._hammerFamily.map((cc) => _ConceptCard(concept: cc)),
              Gap(AppSpacing.md.h),
              _Footer(),
              Gap(AppSpacing.xl.h),
            ],
          ),
        ),
      ),
    );
  }
}

class _Concept {
  const _Concept({
    required this.name,
    required this.stage,
    required this.tagline,
    required this.markPath,
    required this.lockupPath,
    required this.story,
    required this.sells,
    required this.precedent,
  });

  final String name;
  final String stage;
  final String tagline;
  final String markPath;
  final String lockupPath;
  final String story;
  final String sells;
  final String precedent;
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.description});

  final String label;
  final String description;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4.w,
              height: 18.h,
              decoration: BoxDecoration(
                color: c.action,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            Gap(10.w),
            Expanded(
              child: Text(
                label,
                style: tt.titleMedium!.copyWith(
                  color: c.text1,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        Gap(6.h),
        Padding(
          padding: EdgeInsets.only(left: 14.w),
          child: Text(
            description,
            style: tt.bodySmall!.copyWith(
              color: c.text2,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ConceptCard extends StatelessWidget {
  const _ConceptCard({required this.concept});

  final _Concept concept;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.md.h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.md.w,
              vertical: AppSpacing.md.h,
            ),
            decoration: BoxDecoration(
              color: c.background,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8.r),
                topRight: Radius.circular(8.r),
              ),
            ),
            child: Column(
              children: [
                Center(
                  child: SvgPicture.asset(
                    concept.markPath,
                    width: 132.r,
                    height: 132.r,
                  ),
                ),
                Gap(AppSpacing.md.h),
                Center(
                  child: SvgPicture.asset(
                    concept.lockupPath,
                    height: 52.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(AppSpacing.md.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: c.surfaceRaised,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    concept.stage,
                    style: tt.labelSmall!.copyWith(
                      color: c.text2,
                      letterSpacing: 1.2,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Gap(AppSpacing.sm.h),
                Text(
                  concept.name,
                  style: tt.titleLarge!.copyWith(
                    color: c.text1,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
                Gap(4.h),
                Row(
                  children: [
                    Icon(
                      AppIcons.quote,
                      size: AppIconSize.micro.r,
                      color: c.action,
                    ),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        concept.tagline,
                        style: tt.bodyLarge!.copyWith(
                          color: c.action,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                Gap(AppSpacing.sm.h),
                Text(
                  concept.story,
                  style: tt.bodyMedium!.copyWith(
                    color: c.text2,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
                Gap(AppSpacing.md.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: c.actionBg,
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: c.action, width: 1),
                  ),
                  child: Text(
                    concept.sells,
                    style: tt.labelSmall!.copyWith(
                      color: c.actionTx,
                      letterSpacing: 1.5,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Gap(AppSpacing.sm.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      AppIcons.info,
                      size: AppIconSize.micro.r,
                      color: c.text3,
                    ),
                    Gap(6.w),
                    Expanded(
                      child: Text(
                        concept.precedent,
                        style: tt.labelSmall!.copyWith(
                          color: c.text3,
                          fontSize: 11,
                          height: 1.4,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border, width: 1),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.lightningFilled,
                size: AppIconSize.inline.r,
                color: c.action,
              ),
              Gap(8.w),
              Text(
                'CURRENT ACTIVE LOGO',
                style: tt.labelMedium!.copyWith(
                  color: c.text1,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          Gap(AppSpacing.sm.h),
          Text(
            'Active logo is still DUN STAMP (brick-J with orange stamp '
            'block) — kept until you pick a HAMMER-J winner. Tell '
            'Claude which variant to make active and the mark + '
            'lockup will overwrite lib/core/assets/{mark,logo}-jobdun.svg '
            'so all 8 reference sites update automatically. Or ask for '
            'more hammer-J variations.',
            style: tt.bodyMedium!.copyWith(
              color: c.text2,
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
