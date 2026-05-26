import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';

/// One row in the admin verification queue. Flat shape projected from the
/// `verification_documents` table — no domain entity here because the admin
/// view is purely tabular.
class AdminVerificationItem {
  const AdminVerificationItem({
    required this.id,
    required this.tradeId,
    required this.docType,
    required this.status,
    required this.submittedAt,
    required this.filePath,
    this.state,
    this.issuer,
    this.documentNumber,
    this.issuedDate,
    this.expiryDate,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewNotes,
  });

  final String id;
  final String tradeId;
  final String docType;
  final String status; // pending | approved | rejected | expired
  final DateTime submittedAt;
  final String filePath;
  final String? state;
  final String? issuer;
  final String? documentNumber;
  final DateTime? issuedDate;
  final DateTime? expiryDate;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;

  factory AdminVerificationItem.fromJson(Map<String, dynamic> j) {
    DateTime parseDate(Object? v) => DateTime.parse(v as String).toLocal();
    DateTime? parseOptDate(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();
    return AdminVerificationItem(
      id: j['id'] as String,
      tradeId: j['trade_id'] as String,
      docType: j['doc_type'] as String,
      status: j['status'] as String,
      submittedAt: parseDate(j['submitted_at']),
      filePath: j['file_path'] as String,
      state: j['state'] as String?,
      issuer: j['issuer'] as String?,
      documentNumber: j['document_number'] as String?,
      issuedDate: parseOptDate(j['issued_date']),
      expiryDate: parseOptDate(j['expiry_date']),
      reviewedAt: parseOptDate(j['reviewed_at']),
      reviewedBy: j['reviewed_by'] as String?,
      reviewNotes: j['review_notes'] as String?,
    );
  }
}

/// Lists every verification document, newest first, scoped by status.
/// Pending first so the queue shows actionable items at the top.
final adminVerificationsProvider =
    AsyncNotifierProvider<
      AdminVerificationsController,
      List<AdminVerificationItem>
    >(AdminVerificationsController.new);

class AdminVerificationsController
    extends AsyncNotifier<List<AdminVerificationItem>> {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<List<AdminVerificationItem>> build() => _load();

  Future<List<AdminVerificationItem>> _load() async {
    final rows = await _client
        .from('verification_documents')
        .select()
        .isFilter('deleted_at', null)
        .order('submitted_at', ascending: false);
    return (rows as List)
        .map((r) => AdminVerificationItem.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }

  Future<void> setStatus({
    required String id,
    required String status,
    String? notes,
  }) async {
    await _client
        .from('verification_documents')
        .update({
          'status': status,
          'reviewed_at': DateTime.now().toUtc().toIso8601String(),
          'reviewed_by': _client.auth.currentUser?.id,
          if (notes != null && notes.trim().isNotEmpty)
            'review_notes': notes.trim(),
        })
        .eq('id', id);
    await refresh();
  }

  /// Time-limited signed URL so the admin web app can render a private file.
  /// Lives 60 s — long enough to load + view, short enough to not leak.
  Future<String> signedUrl(String filePath) async {
    return _client.storage.from('private-docs').createSignedUrl(filePath, 60);
  }
}
