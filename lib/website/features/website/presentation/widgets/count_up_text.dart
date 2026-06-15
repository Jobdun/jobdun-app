import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// An integer that counts up from zero the first time it's built. Used for the
/// trust stat band — the numbers tick up as the band scrolls into view (the
/// lazily-built sliver constructs this widget when it nears the viewport).
///
/// Honours reduced-motion: when `MediaQuery.disableAnimations` is set the final
/// value is rendered immediately with no tween. Thousands are grouped (12,400).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.duration = const Duration(milliseconds: 1500),
    this.style,
  });

  final int value;
  final String prefix;
  final String suffix;
  final Duration duration;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final grouped = NumberFormat.decimalPattern();
    String render(int v) => '$prefix${grouped.format(v)}$suffix';

    if (MediaQuery.of(context).disableAnimations) {
      return Text(render(value), style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(render(v.round()), style: style),
    );
  }
}
