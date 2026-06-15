import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../providers/active_section_provider.dart';
import '../sections/app_gallery_section.dart';
import '../sections/bottom_cta_section.dart';
import '../sections/built_for_section.dart';
import '../sections/hero_section.dart';
import '../sections/how_it_works_section.dart';
import '../sections/roles_section.dart';
import '../sections/site_footer.dart';
import '../sections/site_top_bar.dart';
import '../sections/values_strip.dart';
import '../widgets/blueprint_grid_background.dart';
import '../widgets/orange_rule.dart';
import '../widgets/watermark_mark.dart';

/// Single-page marketing site for Jobdun.
///
/// Composition (top to bottom) — no two consecutive sections share
/// a layout rhythm:
///   1. Sticky `SiteTopBar`.
///   2. `HeroSection`         — text on the left, real app on the right.
///   3. `BuiltForSection`     — long-form editorial prose, with a
///                                watermark hammer-J as anchor.
///   4. `ValuesStrip`         — three short value props, no header.
///   5. `HowItWorksSection`   — three vector illustrations, no header.
///   6. `RolesSection`        — two large phones, swipeable on mobile.
///   7. `BottomCtaSection`    — single column, mark + headline.
///   8. `SiteFooter`          — privacy / delete / contact.
///
/// The page background is a faint blueprint grid (56px squares, 18%
/// alpha) — reads as the graph paper of a job-site clipboard, never
/// as a "decoration". Each section sits on top of the grid via the
/// `BlueprintGridBackground` widget.
class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key, this.initialFragment});

  final String? initialFragment;

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final ScrollController _scroll;
  final _topKey = GlobalKey();
  final _hiringKey = GlobalKey();
  final _crewsKey = GlobalKey();
  final _appKey = GlobalKey();
  bool _initialScrolled = false;

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    _scroll.addListener(_updateActive);
  }

  @override
  void dispose() {
    _scroll.removeListener(_updateActive);
    _scroll.dispose();
    super.dispose();
  }

  void _updateActive() {
    final positions = {'hiring': _hiringKey, 'crews': _crewsKey};
    SiteSection? next;
    double bestDistance = double.infinity;
    final viewportTop = _scroll.hasClients ? _scroll.offset : 0.0;
    positions.forEach((id, key) {
      final box = key.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final pos = box.localToGlobal(Offset.zero).dy;
      if (pos <= viewportTop + 120) {
        final dist = (pos - viewportTop).abs();
        if (dist < bestDistance) {
          bestDistance = dist;
          next = switch (id) {
            'hiring' => SiteSection.hiring,
            'crews' => SiteSection.crews,
            _ => null,
          };
        }
      }
    });
    if (ref.read(activeSectionProvider) != next) {
      ref.read(activeSectionProvider.notifier).set(next);
    }
  }

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
  }

  void _scrollToId(String id) {
    final key = switch (id) {
      'top' => _topKey,
      'hiring' => _hiringKey,
      'crews' => _crewsKey,
      'app' => _appKey,
      _ => _topKey,
    };
    _scrollToKey(key);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialScrolled) {
      _initialScrolled = true;
      final frag = widget.initialFragment;
      if (frag != null && frag.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToId(frag);
        });
      }
    }

    ref.listen(scrollToProvider, (_, next) {
      if (next != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToId(next.id);
          ref.read(scrollToProvider.notifier).clear();
        });
      }
    });

    final c = context.c;

    return Scaffold(
      backgroundColor: c.background,
      // The blueprint grid is the page background. Every section
      // paints its own colour over the top (c.background or
      // c.surface), but the grid is visible in the *gaps* between
      // sections where neither colour covers it.
      body: Stack(
        children: [
          const Positioned.fill(
            child: BlueprintGridBackground(spacing: 56, minor: true),
          ),
          Positioned.fill(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: SizedBox(key: _topKey, height: 0)),
                const SliverToBoxAdapter(child: HeroSection()),
                // BuiltFor sits on a slightly tinted section bg so the
                // grid fades behind it; the watermark anchor lives here.
                SliverToBoxAdapter(
                  child: Stack(
                    children: [
                      const BuiltForSection(),
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: WatermarkMark(
                            alignment: Alignment.topRight,
                            size: 320,
                            opacity: 0.045,
                            tilt: -0.05,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Orange rule between BuiltFor and ValuesStrip — the
                // first hard rhythm break after the editorial prose.
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: OrangeRule(width: 64, thickness: 4)),
                  ),
                ),
                const SliverToBoxAdapter(child: ValuesStrip()),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: OrangeRule(width: 48, thickness: 3)),
                  ),
                ),
                const SliverToBoxAdapter(child: HowItWorksSection()),
                SliverToBoxAdapter(child: SizedBox(key: _hiringKey, height: 0)),
                const SliverToBoxAdapter(child: RolesSection()),
                const SliverToBoxAdapter(child: AppGallerySection()),
                SliverToBoxAdapter(child: SizedBox(key: _crewsKey, height: 0)),
                SliverToBoxAdapter(child: SizedBox(key: _appKey, height: 0)),
                const SliverToBoxAdapter(child: BottomCtaSection()),
                const SliverToBoxAdapter(child: Gap(48)),
                const SliverToBoxAdapter(child: SiteFooter()),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SiteTopBar(onGetTheApp: () => _scrollToId('app')),
          ),
        ],
      ),
    );
  }
}
