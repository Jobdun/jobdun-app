import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';

/// Coarse classification used by the admin queue chips. Maps from the
/// `verification_documents.doc_type` value to a role-scoped audience so
/// reviewers can triage by who-uploaded-what without reading every row.
enum AdminVerificationKind { tradeLicence, builderAbn, other }

AdminVerificationKind _kindForDocType(String docType) => switch (docType) {
  'trade_licence' => AdminVerificationKind.tradeLicence,
  'abn_certificate' => AdminVerificationKind.builderAbn,
  _ => AdminVerificationKind.other,
};

/// One row in the admin verification queue. Flat shape projected from
/// `verification_documents` + a `profiles` join (display name) + a
/// `user_roles` join (role label) + the user's most recent matching
/// `verifications` row (so the admin can see *why* the API path didn't
/// catch this user automatically).
class AdminVerificationItem {
  const AdminVerificationItem({
    required this.id,
    required this.tradeId,
    required this.docType,
    required this.kind,
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
    this.userDisplayName,
    this.userRole,
    this.lastVerificationStatus,
    this.lastVerificationFailureReason,
  });

  final String id;
  final String tradeId;
  final String docType;
  final AdminVerificationKind kind;
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
  final String? userDisplayName;
  final String? userRole;
  final String? lastVerificationStatus;
  final String? lastVerificationFailureReason;

  String get displayName => (userDisplayName?.trim().isNotEmpty ?? false)
      ? userDisplayName!.trim()
      : '${tradeId.substring(0, 8)}…';

  String get roleLabel =>
      (userRole == null) ? 'UNKNOWN' : userRole!.toUpperCase();
}

class AdminVerificationsState {
  const AdminVerificationsState({required this.items, required this.filter});

  final List<AdminVerificationItem> items;
  final AdminVerificationKindFilter filter;

  AdminVerificationsState copyWith({
    List<AdminVerificationItem>? items,
    AdminVerificationKindFilter? filter,
  }) => AdminVerificationsState(
    items: items ?? this.items,
    filter: filter ?? this.filter,
  );

  /// Items after the active chip filter.
  List<AdminVerificationItem> get filteredItems => switch (filter) {
    AdminVerificationKindFilter.all => items,
    AdminVerificationKindFilter.tradeLicence =>
      items.where((i) => i.kind == AdminVerificationKind.tradeLicence).toList(),
    AdminVerificationKindFilter.builderAbn =>
      items.where((i) => i.kind == AdminVerificationKind.builderAbn).toList(),
    AdminVerificationKindFilter.other =>
      items.where((i) => i.kind == AdminVerificationKind.other).toList(),
  };

  int countFor(AdminVerificationKindFilter f) => switch (f) {
    AdminVerificationKindFilter.all => items.length,
    AdminVerificationKindFilter.tradeLicence =>
      items.where((i) => i.kind == AdminVerificationKind.tradeLicence).length,
    AdminVerificationKindFilter.builderAbn =>
      items.where((i) => i.kind == AdminVerificationKind.builderAbn).length,
    AdminVerificationKindFilter.other =>
      items.where((i) => i.kind == AdminVerificationKind.other).length,
  };
}

enum AdminVerificationKindFilter { all, tradeLicence, builderAbn, other }

final adminVerificationsProvider =
    AsyncNotifierProvider<
      AdminVerificationsController,
      AdminVerificationsState
    >(AdminVerificationsController.new);

class AdminVerificationsController
    extends AsyncNotifier<AdminVerificationsState> {
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<AdminVerificationsState> build() => _load();

  Future<AdminVerificationsState> _load({
    AdminVerificationKindFilter? keepFilter,
  }) async {
    // 1. Documents + profile.display_name in one shot via FK embed.
    final docRows = await _client
        .from('verification_documents')
        .select(
          '*, profiles!verification_documents_trade_id_fkey(display_name)',
        )
        .isFilter('deleted_at', null)
        .order('submitted_at', ascending: false);
    final rawDocs = (docRows as List).cast<Map<String, dynamic>>();
    final userIds = rawDocs
        .map((r) => r['trade_id'] as String)
        .toSet()
        .toList();

    // 2. Roles for every uploader.
    final roleRows = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                  .from('user_roles')
                  .select('user_id, role')
                  .inFilter('user_id', userIds))
              .cast<Map<String, dynamic>>();
    final roleByUser = <String, String>{
      for (final r in roleRows) r['user_id'] as String: r['role'] as String,
    };

    // 3. Latest verification per (user, kind). Used to show "why the API
    // path didn't catch this user" in the queue + review sheet.
    final verifRows = userIds.isEmpty
        ? <Map<String, dynamic>>[]
        : (await _client
                  .from('verifications')
                  .select('user_id, kind, status, failure_reason, updated_at')
                  .inFilter('user_id', userIds)
                  .order('updated_at', ascending: false))
              .cast<Map<String, dynamic>>();
    // Reduce to the latest row per (user_id, kind).
    final latestVerifByPair = <String, Map<String, dynamic>>{};
    for (final r in verifRows) {
      final key = '${r['user_id']}::${r['kind']}';
      latestVerifByPair.putIfAbsent(key, () => r);
    }

    final items = rawDocs
        .map((r) => _projectRow(r, roleByUser, latestVerifByPair))
        .toList();
    final currentFilter =
        keepFilter ?? state.value?.filter ?? AdminVerificationKindFilter.all;
    return AdminVerificationsState(items: items, filter: currentFilter);
  }

  AdminVerificationItem _projectRow(
    Map<String, dynamic> row,
    Map<String, String> roleByUser,
    Map<String, Map<String, dynamic>> latestVerifByPair,
  ) {
    DateTime parseDate(Object? v) => DateTime.parse(v as String).toLocal();
    DateTime? parseOptDate(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();
    final tradeId = row['trade_id'] as String;
    final docType = row['doc_type'] as String;
    final kind = _kindForDocType(docType);
    final profile = row['profiles'] as Map<String, dynamic>?;
    final verifKind = kind == AdminVerificationKind.tradeLicence
        ? 'licence'
        : kind == AdminVerificationKind.builderAbn
        ? 'abn'
        : null;
    final lastVerif = verifKind == null
        ? null
        : latestVerifByPair['$tradeId::$verifKind'];
    return AdminVerificationItem(
      id: row['id'] as String,
      tradeId: tradeId,
      docType: docType,
      kind: kind,
      status: row['status'] as String,
      submittedAt: parseDate(row['submitted_at']),
      filePath: row['file_path'] as String,
      state: row['state'] as String?,
      issuer: row['issuer'] as String?,
      documentNumber: row['document_number'] as String?,
      issuedDate: parseOptDate(row['issued_date']),
      expiryDate: parseOptDate(row['expiry_date']),
      reviewedAt: parseOptDate(row['reviewed_at']),
      reviewedBy: row['reviewed_by'] as String?,
      reviewNotes: row['review_notes'] as String?,
      userDisplayName: profile?['display_name'] as String?,
      userRole: roleByUser[tradeId],
      lastVerificationStatus: lastVerif?['status'] as String?,
      lastVerificationFailureReason: lastVerif?['failure_reason'] as String?,
    );
  }

  Future<void> refresh() async {
    final previousFilter = state.value?.filter;
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(keepFilter: previousFilter));
  }

  void setFilter(AdminVerificationKindFilter filter) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(filter: filter));
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
  /// 60s — long enough to load + view, short enough not to leak.
  Future<String> signedUrl(String filePath) async {
    return _client.storage.from('private-docs').createSignedUrl(filePath, 60);
  }
}
