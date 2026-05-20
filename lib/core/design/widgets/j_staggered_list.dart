import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:gap/gap.dart';

/// Drop-in replacement for `ListView.separated` that fades and slides each
/// item in on first build.
///
/// MASTER §motion. 200ms per item, 16dp upward slide — matches the
/// 150–200ms ease window the brand standardised on. Respects the OS-level
/// reduce-motion flag (`MediaQuery.disableAnimations`); when that's on,
/// items render with no animation at all.
///
/// Scope. First-render motion only. If the list rebuilds without the
/// `AnimationLimiter` key changing (e.g., tab/filter swap), items will
/// **not** re-stagger — that's intentional; re-animating on every filter
/// tap reads as noise. To force a re-stagger, pass a fresh [animationKey].
class JStaggeredList extends StatelessWidget {
  const JStaggeredList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding,
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    this.animationKey,
    this.verticalOffset,
    this.duration = const Duration(milliseconds: 200),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Defaults to `Gap(9.h)` — the house separator across job, application,
  /// and message lists.
  final IndexedWidgetBuilder? separatorBuilder;

  final EdgeInsetsGeometry? padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool shrinkWrap;

  /// Force the limiter to re-trigger by changing this key — e.g. on tab
  /// change. Null means animate once per mount.
  final Key? animationKey;

  /// Slide offset in logical pixels; defaults to 16. Passed through `.h`
  /// scaling internally.
  final double? verticalOffset;

  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final separator =
        separatorBuilder ?? (BuildContext context, int index) => Gap(9.h);

    if (reduceMotion) {
      return ListView.separated(
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: separator,
        itemBuilder: itemBuilder,
      );
    }

    return AnimationLimiter(
      key: animationKey,
      child: ListView.separated(
        controller: controller,
        physics: physics,
        shrinkWrap: shrinkWrap,
        padding: padding,
        itemCount: itemCount,
        separatorBuilder: separator,
        itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
          position: i,
          duration: duration,
          child: SlideAnimation(
            verticalOffset: (verticalOffset ?? 16).h,
            child: FadeInAnimation(child: itemBuilder(ctx, i)),
          ),
        ),
      ),
    );
  }
}

/// Sliver-friendly variant of [JStaggeredList] for screens built on
/// `CustomScrollView` (e.g. the home feed). Stagger applies to the rendered
/// list as a single non-lazy block — fine for the small "feed preview"
/// case (≤ ~20 items). For larger lists prefer [JStaggeredList].
class JStaggeredSliverList extends StatelessWidget {
  const JStaggeredSliverList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.separator,
    this.animationKey,
    this.verticalOffset,
    this.duration = const Duration(milliseconds: 200),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Inserted between items. Defaults to `Gap(9.h)`.
  final Widget? separator;

  final Key? animationKey;
  final double? verticalOffset;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final gap = separator ?? Gap(9.h);

    Widget buildItem(int i) {
      final tile = itemBuilder(context, i);
      if (reduceMotion) return tile;
      return AnimationConfiguration.staggeredList(
        position: i,
        duration: duration,
        child: SlideAnimation(
          verticalOffset: (verticalOffset ?? 16).h,
          child: FadeInAnimation(child: tile),
        ),
      );
    }

    final children = <Widget>[];
    for (var i = 0; i < itemCount; i++) {
      children.add(buildItem(i));
      if (i < itemCount - 1) children.add(gap);
    }

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );

    return SliverToBoxAdapter(
      child: reduceMotion
          ? column
          : AnimationLimiter(key: animationKey, child: column),
    );
  }
}
