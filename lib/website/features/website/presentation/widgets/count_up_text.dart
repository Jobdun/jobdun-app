import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// An integer that counts up from zero the first time it scrolls into view.
/// Used for the trust stat band; a [VisibilityDetector] starts the tween when
/// the number is actually on screen, so the count is never missed off-screen.
///
/// Honours reduced-motion: when `MediaQuery.disableAnimations` is set the final
/// value is rendered immediately with no tween. Thousands are grouped (12,400).
class CountUpText extends StatefulWidget {
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
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText> {
  final Key _detectorKey = UniqueKey();
  bool _started = false;

  String _render(int v) =>
      '${widget.prefix}${NumberFormat.decimalPattern().format(v)}${widget.suffix}';

  void _onVisibility(VisibilityInfo info) {
    if (!_started && info.visibleFraction > 0.1 && mounted) {
      setState(() => _started = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(_render(widget.value), style: widget.style);
    }

    return VisibilityDetector(
      key: _detectorKey,
      onVisibilityChanged: _onVisibility,
      child: _started
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: widget.value.toDouble()),
              duration: widget.duration,
              curve: Curves.easeOutCubic,
              builder: (context, v, _) =>
                  Text(_render(v.round()), style: widget.style),
            )
          : Text(_render(0), style: widget.style),
    );
  }
}
