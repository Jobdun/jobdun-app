import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Bottom card carousel for map browsing (map verdict #1, Airbnb pattern):
/// swiping cards drives pin selection, tapping pins snaps the carousel —
/// the caller owns the [PageController] and the two-way sync; this widget
/// owns the geometry (thumb-zone height, peeking neighbours).
class JMapCarousel extends StatelessWidget {
  const JMapCarousel({
    super.key,
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onPageChanged,
  });

  final PageController controller;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96.h,
      child: PageView.builder(
        controller: controller,
        itemCount: itemCount,
        onPageChanged: onPageChanged,
        itemBuilder: (context, i) => Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: itemBuilder(context, i),
        ),
      ),
    );
  }
}
