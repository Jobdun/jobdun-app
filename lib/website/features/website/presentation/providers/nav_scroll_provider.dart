import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True once the page has scrolled past the top. Drives the floating nav's
/// frosted-glass treatment: transparent at the very top, frosted + hairline
/// border once content scrolls under it. Set by `SiteShell`'s scroll listener
/// and read by `SiteTopBar`.
class NavScrolledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) {
    if (state != value) state = value;
  }
}

final navScrolledProvider = NotifierProvider<NavScrolledNotifier, bool>(
  NavScrolledNotifier.new,
);
