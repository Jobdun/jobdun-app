import 'package:flutter/material.dart';

import '../../../../../core/design/colors.dart';

/// A bordered card that lifts a few pixels and brightens its border to the
/// brand orange on hover — the single card-depth the refined-flat+ marketing
/// direction allows. Lift is suppressed under reduced-motion.
///
/// Shared by the features grid and the testimonial wall so card behaviour is
/// identical across the site.
class HoverLiftCard extends StatefulWidget {
  const HoverLiftCard({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;

  /// Card fill. Defaults to `c.surface`; pass `c.background` when the card
  /// sits on a `c.surface` section so it still reads as a distinct tile.
  final Color? backgroundColor;
  final EdgeInsets padding;

  @override
  State<HoverLiftCard> createState() => _HoverLiftCardState();
}

class _HoverLiftCardState extends State<HoverLiftCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final lift = _hovered && !reduceMotion ? -4.0 : 0.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, lift, 0),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? c.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: _hovered ? c.action : c.border),
        ),
        child: widget.child,
      ),
    );
  }
}
