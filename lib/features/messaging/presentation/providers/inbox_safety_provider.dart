import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/current_user_provider.dart';
import '../../domain/entities/report_submission.dart';
import '../../domain/usecases/block_user.dart';
import '../../domain/usecases/report_user.dart';
import '../../domain/usecases/unblock_user.dart';
import 'messaging_provider.dart';

// Block + report (Phase D safety) — separate controller so
// messaging_provider.dart stays under the 500-LOC ceiling, and because the
// sheets need their own loading/error state independent of the inbox.

final blockUserUseCaseProvider = Provider(
  (ref) => BlockUser(ref.read(messageRepositoryProvider)),
);

final reportUserUseCaseProvider = Provider(
  (ref) => ReportUser(ref.read(messageRepositoryProvider)),
);

final unblockUserUseCaseProvider = Provider(
  (ref) => UnblockUser(ref.read(messageRepositoryProvider)),
);

class InboxSafetyState {
  const InboxSafetyState({this.isLoading = false, this.error});
  final bool isLoading;
  final String? error;

  InboxSafetyState copyWith({bool? isLoading, String? error}) =>
      InboxSafetyState(isLoading: isLoading ?? this.isLoading, error: error);
}

final inboxSafetyControllerProvider =
    NotifierProvider<InboxSafetyController, InboxSafetyState>(
      InboxSafetyController.new,
    );

class InboxSafetyController extends Notifier<InboxSafetyState> {
  @override
  InboxSafetyState build() => const InboxSafetyState();

  /// Blocks [blockedId] user-wide and freezes [conversationId]. On success the
  /// inbox is refreshed in place (keeps the realtime streams alive) so the row
  /// flips to its BLOCKED state immediately.
  Future<bool> blockUser({
    required String blockedId,
    required String conversationId,
  }) async {
    final blockerId = readCurrentUserId(ref);
    if (blockerId == null) return false;
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref
        .read(blockUserUseCaseProvider)
        .call(
          blockerId: blockerId,
          blockedId: blockedId,
          conversationId: conversationId,
        );
    state = result.fold(
      (f) => state.copyWith(isLoading: false, error: f.message),
      (_) => const InboxSafetyState(),
    );
    if (result.isRight()) {
      await ref.read(messagingControllerProvider.notifier).refreshInbox();
    }
    return result.isRight();
  }

  /// Whether I am the one blocking [otherId] — decides if the long-press
  /// sheet on a frozen thread offers UNBLOCK. Errors degrade to false.
  Future<bool> amIBlocking(String otherId) async {
    final result = await ref
        .read(messageRepositoryProvider)
        .amIBlocking(otherId);
    return result.fold((_) => false, (v) => v);
  }

  /// Reverses a block (delete my row + unfreeze the thread server-side) and
  /// refreshes the inbox in place.
  Future<bool> unblockUser({
    required String blockedId,
    required String conversationId,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref
        .read(unblockUserUseCaseProvider)
        .call(blockedId: blockedId, conversationId: conversationId);
    state = result.fold(
      (f) => state.copyWith(isLoading: false, error: f.message),
      (_) => const InboxSafetyState(),
    );
    if (result.isRight()) {
      await ref.read(messagingControllerProvider.notifier).refreshInbox();
    }
    return result.isRight();
  }

  Future<bool> reportUser(ReportSubmission report) async {
    state = state.copyWith(isLoading: true, error: null);
    final result = await ref.read(reportUserUseCaseProvider).call(report);
    state = result.fold(
      (f) => state.copyWith(isLoading: false, error: f.message),
      (_) => const InboxSafetyState(),
    );
    return result.isRight();
  }
}
