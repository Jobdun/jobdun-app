import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/ftue_service.dart';

// Mirrors the FtueService SharedPreferences value into a synchronous Riverpod
// state so the GoRouter redirect can branch on it without awaiting. The
// router listens for changes and refreshes itself, same pattern used by
// authControllerProvider.
//
// While `isLoaded == false` the router keeps the user on /splash so we never
// flash the wrong screen.
final ftueGateProvider = NotifierProvider<FtueGate, FtueGateState>(
  FtueGate.new,
);

class FtueGate extends Notifier<FtueGateState> {
  @override
  FtueGateState build() {
    Future.microtask(_load);
    return const FtueGateState(isLoaded: false, hasCompleted: false);
  }

  Future<void> _load() async {
    final done = await FtueService.hasCompletedFtue();
    state = FtueGateState(isLoaded: true, hasCompleted: done);
  }

  // Used by the router as a safety net the first time a pre-existing user
  // authenticates — they shouldn't ever see the carousel retroactively.
  Future<void> markCompleted() async {
    if (state.hasCompleted) return;
    await FtueService.markFtueComplete();
    state = const FtueGateState(isLoaded: true, hasCompleted: true);
  }

  Future<void> reload() async {
    state = const FtueGateState(isLoaded: false, hasCompleted: false);
    await _load();
  }
}

class FtueGateState {
  const FtueGateState({required this.isLoaded, required this.hasCompleted});

  final bool isLoaded;
  final bool hasCompleted;
}
