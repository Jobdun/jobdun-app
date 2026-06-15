import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Currently-visible section in the marketing site's top-bar nav.
///
/// Riverpod 3 dropped the public `StateProvider` from the top-level API;
/// this [ActiveSectionNotifier] is the equivalent for a single piece of
/// nullable UI state. Updated by `HomePage`'s scroll listener; read by the
/// top bar to highlight the active nav link.
enum SiteSection { how, hiring, crews }

class ActiveSectionNotifier extends Notifier<SiteSection?> {
  @override
  SiteSection? build() => null;

  void set(SiteSection? value) => state = value;
}

final activeSectionProvider =
    NotifierProvider<ActiveSectionNotifier, SiteSection?>(
      ActiveSectionNotifier.new,
    );

/// Imperative scroll-to target exposed for the top bar's nav links and
/// the in-page CTAs. `HomePage` owns the [ScrollController] and listens
/// to this provider; setting a value scrolls on the next frame, then
/// nulls itself out so the same id can be triggered again.
class ScrollToRequest {
  const ScrollToRequest(this.id);
  final String id;
}

class ScrollToNotifier extends Notifier<ScrollToRequest?> {
  @override
  ScrollToRequest? build() => null;

  void request(String id) => state = ScrollToRequest(id);
  void clear() => state = null;
}

final scrollToProvider =
    NotifierProvider<ScrollToNotifier, ScrollToRequest?>(ScrollToNotifier.new);
