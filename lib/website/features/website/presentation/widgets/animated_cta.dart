import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/theme/app_icons.dart';

/// The site's primary call-to-action button.
///
/// - Filled (orange) or secondary (raised) variants.
/// - On hover it lifts slightly and the trailing arrow nudges right.
/// - All motion is suppressed under reduced-motion; the button stays fully
///   functional.
/// - Pass [route] to navigate via GoRouter, or [onPressed] for a custom action.
class AnimatedCta extends StatefulWidget {
  const AnimatedCta({
    super.key,
    required this.label,
    this.route,
    this.onPressed,
    this.filled = true,
    this.icon = AppIcons.arrowRight,
  });

  final String label;
  final String? route;
  final VoidCallback? onPressed;
  final bool filled;
  final IconData? icon;

  @override
  State<AnimatedCta> createState() => _AnimatedCtaState();
}

class _AnimatedCtaState extends State<AnimatedCta> {
  bool _hovered = false;

  void _activate() {
    if (widget.route != null) {
      context.go(widget.route!);
    } else {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    final bg = widget.filled ? c.action : c.surfaceRaised;
    final fg = widget.filled ? c.onAction : c.text1;

    Widget button = Material(
      color: _hovered && widget.filled ? c.actionPressed : bg,
      borderRadius: BorderRadius.circular(AppRadius.btn),
      child: InkWell(
        onTap: _activate,
        borderRadius: BorderRadius.circular(AppRadius.btn),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.label, style: tt.labelLarge!.copyWith(color: fg)),
              if (widget.icon != null) ...[
                const SizedBox(width: 10),
                AnimatedSlide(
                  offset: _hovered && !reduceMotion
                      ? const Offset(0.25, 0)
                      : Offset.zero,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOut,
                  child: Icon(widget.icon, size: 18, color: fg),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: button,
      ),
    );
  }
}
