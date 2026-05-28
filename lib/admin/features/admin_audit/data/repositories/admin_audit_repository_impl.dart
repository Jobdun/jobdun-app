import 'dart:convert';

import 'package:fpdart/fpdart.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_audit_event.dart';
import '../../domain/repositories/admin_audit_repository.dart';

/// Merges events from two append-only audit tables:
///   - verification_events  (id, verification_id, event_type, raw_response,
///                           actor_id, created_at)
///   - user_role_events     (id, user_id, old_role, new_role, changed_by,
///                           reason, created_at)
///
/// Schema note: verification_events joins through verifications!inner to
/// resolve the actual user_id; actor_id (the admin who triggered the event)
/// maps to actorId. Events pointing at deleted verifications are excluded
/// by the !inner join (orphaned events have no meaningful target user).
class AdminAuditRepositoryImpl implements AdminAuditRepository {
  AdminAuditRepositoryImpl({SupabaseClient? client})
      : _client = client ?? SupabaseConfig.client;

  final SupabaseClient _client;

  @override
  Future<Either<Failure, List<AdminAuditEvent>>> listEvents({
    required int limit,
    required int offset,
  }) async {
    try {
      // Over-fetch from each source, then merge + sort + paginate in memory.
      // Acceptable for the small admin event volumes; revisit if tables grow.
      final fetchUpper = limit + offset;

      final results = await Future.wait([
        _fetchVerification(fetchUpper),
        _fetchRole(fetchUpper),
      ]);
      final merged = [...results[0], ...results[1]]
        ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

      final start = offset.clamp(0, merged.length);
      final end = (offset + limit).clamp(0, merged.length);
      return Right(merged.sublist(start, end));
    } on PostgrestException catch (e) {
      return Left(ServerFailure(e.message));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<List<AdminAuditEvent>> _fetchVerification(int limit) async {
    final rows = await _client
        .from('verification_events')
        .select(
          'id, verification_id, event_type, actor_id, raw_response, '
          'created_at, verifications!inner(user_id)',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final eventType = r['event_type'] as String?;

      // Resolve the actual user who owns the verification.
      final verif = r['verifications'] as Map<String, dynamic>?;
      final targetUser = verif?['user_id'] as String?;

      // Build a 1-line JSON preview from raw_response (capped at 120 chars).
      final raw = r['raw_response'];
      String? preview;
      if (raw is Map) {
        preview = jsonEncode(raw);
      } else if (raw is String) {
        preview = raw;
      }
      if (preview != null && preview.length > 120) {
        preview = '${preview.substring(0, 120)}…';
      }

      return AdminAuditEvent(
        id: 'v:${r['id']}',
        occurredAt: DateTime.parse(r['created_at'] as String).toLocal(),
        source: AdminAuditSource.verification,
        eventType: eventType ?? 'verif.event',
        actorId: r['actor_id'] as String?,
        targetUserId: targetUser,
        payloadPreview: preview,
      );
    }).toList();
  }

  Future<List<AdminAuditEvent>> _fetchRole(int limit) async {
    final rows = await _client
        .from('user_role_events')
        .select(
          'id, user_id, old_role, new_role, changed_by, reason, created_at',
        )
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>().map((r) {
      final oldRole = r['old_role'] as String?;
      final newRole = r['new_role'] as String?;
      final reason = r['reason'] as String?;
      return AdminAuditEvent(
        id: 'r:${r['id']}',
        occurredAt: DateTime.parse(r['created_at'] as String).toLocal(),
        source: AdminAuditSource.role,
        eventType: 'role.${oldRole ?? '?'}→${newRole ?? '?'}',
        actorId: r['changed_by'] as String?,
        targetUserId: r['user_id'] as String?,
        payloadPreview: reason,
      );
    }).toList();
  }
}
