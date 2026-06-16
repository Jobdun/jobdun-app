import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../providers/nav_scroll_provider.dart';
import '../sections/site_footer.dart';
import '../sections/site_top_bar.dart';
import 'blueprint_grid_background.dart';

/// Shared chrome for every marketing-site page.
///
/// Owns the page scroll controller (driving the floating nav's frosted
/// treatment via [navScrolledProvider]), paints the blueprint grid behind the
/// content, appends the shared footer, and floats the router-aware [SiteTopBar]
/// over the top. A page supplies only its body [slivers].
class SiteShell extends ConsumerStatefulWidget {
  const SiteShell({super.key, required this.slivers});

  final List<Widget> slivers;

  @override
  ConsumerState<SiteShell> createState() => _SiteShellState();
}

class _SiteShellState extends ConsumerState<SiteShell> {
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController()..addListener(_onScroll);
    // Each page starts at the top — reset the nav's frosted flag so a route
    // change from a scrolled page doesn't carry a stale state in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(navScrolledProvider.notifier).set(false);
    });
  }

  void _onScroll() {
    ref
        .read(navScrolledProvider.notifier)
        .set(_scroll.hasClients && _scroll.offset > 8);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          const Positioned.fill(
            child: BlueprintGridBackground(spacing: 56, minor: true),
          ),
          Positioned.fill(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                ...widget.slivers,
                const SliverToBoxAdapter(child: Gap(48)),
                const SliverToBoxAdapter(child: SiteFooter()),
              ],
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: SiteTopBar()),
        ],
      ),
    );
  }
}
