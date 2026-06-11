part of 'message_remote_datasource.dart';

/// Phase D inbox-safety operations for [MessageRemoteDataSourceImpl], split
/// into a part-file mixin to keep the datasource under the file-size budget
/// (same recipe as the controller's _InboxActions).
mixin _InboxSafetyRemote {
  SupabaseClient get _client;

  Future<void> pinConversation({
    required String conversationId,
    required bool isBuilder,
    required bool pin,
  }) async {
    try {
      final column = isBuilder ? 'builder_pinned_at' : 'trade_pinned_at';
      await _client
          .from('conversations')
          .update({column: pin ? DateTime.now().toIso8601String() : null})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> muteConversation({
    required String conversationId,
    required bool isBuilder,
    required bool mute,
  }) async {
    try {
      final column = isBuilder ? 'builder_muted_at' : 'trade_muted_at';
      await _client
          .from('conversations')
          .update({column: mute ? DateTime.now().toIso8601String() : null})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // Mark-unread sentinel (spec D-6): null last-read + unread count 1 restores
  // the badge without a dedicated column.
  Future<void> markConversationUnread({
    required String conversationId,
    required bool isBuilder,
  }) async {
    try {
      final readAtCol = isBuilder
          ? 'builder_last_read_at'
          : 'trade_last_read_at';
      final unreadCol = isBuilder
          ? 'builder_unread_count'
          : 'trade_unread_count';
      await _client
          .from('conversations')
          .update({readAtCol: null, unreadCol: 1})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  // User-level block (spec D-7): idempotent insert; the conversation status
  // flips to 'blocked' as the durable UI signal. The DB-side send guard and
  // get_or_create_conversation guard live in migration 20260611000006.
  Future<void> blockUser({
    required String blockerId,
    required String blockedId,
    required String conversationId,
  }) async {
    try {
      await _client
          .from('blocks')
          .upsert(
            {'blocker_id': blockerId, 'blocked_id': blockedId},
            onConflict: 'blocker_id,blocked_id',
            ignoreDuplicates: true,
          );
      await _client
          .from('conversations')
          .update({'status': 'blocked'})
          .eq('id', conversationId);
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  Future<void> reportUser(ReportSubmission report) async {
    try {
      await _client.from('reports').insert({
        'reporter_id': report.reporterId,
        'reported_id': report.reportedId,
        'conversation_id': report.conversationId,
        if (report.messageId != null) 'message_id': report.messageId,
        'reason': report.reason.dbValue,
        if (report.details != null && report.details!.isNotEmpty)
          'details': report.details,
      });
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
