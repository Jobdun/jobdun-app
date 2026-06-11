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
      // One pending report per (reporter, conversation) — the unique index
      // from 20260612000001 turns queue-flooding into a friendly no-op.
      final msg = e.toString();
      if (msg.contains('reports_one_pending_per_conversation') ||
          msg.contains('23505')) {
        throw const ServerException(
          "You've already reported this conversation — our team is "
          'reviewing it.',
        );
      }
      throw ServerException(msg);
    }
  }

  /// Whether I currently block [blockedId] (RLS only shows my own rows, so
  /// this can't leak the reverse direction).
  Future<bool> amIBlocking(String blockedId) async {
    try {
      final rows = await _client
          .from('blocks')
          .select('blocked_id')
          .eq('blocked_id', blockedId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      throw ServerException(e.toString());
    }
  }

  /// Reverses [blockUser]: removes my block row and, only if one actually
  /// existed, unfreezes the conversation. The returning select makes the
  /// status restore conditional so the non-blocker can't unfreeze a thread
  /// the OTHER side blocked.
  Future<void> unblockUser({
    required String blockedId,
    required String conversationId,
  }) async {
    try {
      final deleted = await _client
          .from('blocks')
          .delete()
          .eq('blocked_id', blockedId)
          .select('blocked_id');
      if ((deleted as List).isNotEmpty) {
        await _client
            .from('conversations')
            .update({'status': 'active'})
            .eq('id', conversationId);
      }
    } catch (e) {
      throw ServerException(e.toString());
    }
  }
}
