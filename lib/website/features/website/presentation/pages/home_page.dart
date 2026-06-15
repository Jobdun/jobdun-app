import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../providers/active_section_provider.dart';
import '../sections/bottom_cta_section.dart';
import '../sections/built_for_section.dart';
import '../sections/hero_section.dart';
import '../sections/how_it_works_section.dart';
import '../sections/roles_section.dart';
import '../sections/site_footer.dart';
import '../sections/site_top_bar.dart';
import '../sections/values_strip.dart';

/// Single-page marketing site for Jobdun.
///
/// Composition (top to bottom) — no two consecutive sections share a
/// layout rhythm:
///   1. Sticky `SiteTopBar`.
///   2. `HeroSection`         — text on the left, real app screenshot
///                                on the right (product moment).
///   3. `BuiltForSection`     — long-form editorial paragraph, no
///                                widgets, no cards.
///   4. `ValuesStrip`         — three short value props with orange
///                                ticks, no section header above.
///   5. `HowItWorksSection`   — three vector illustrations + a
///                                sentence each. No screenshots.
///   6. `RolesSection`        — two large phones, one per role,
///                                no card chrome.
///   7. `BottomCtaSection`    — single column, mark + headline +
///                                store buttons.
///   8. `SiteFooter`          — privacy / delete / contact.
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
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomScrollView(
              controller: _scroll,
              slivers: [
                SliverToBoxAdapter(child: SizedBox(key: _topKey, height: 0)),
                const SliverToBoxAdapter(child: HeroSection()),
                const SliverToBoxAdapter(child: BuiltForSection()),
                const SliverToBoxAdapter(child: ValuesStrip()),
                const SliverToBoxAdapter(child: HowItWorksSection()),
                SliverToBoxAdapter(child: SizedBox(key: _hiringKey, height: 0)),
                const SliverToBoxAdapter(child: RolesSection()),
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
