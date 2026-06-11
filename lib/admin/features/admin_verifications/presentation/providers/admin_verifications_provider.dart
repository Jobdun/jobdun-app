import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../../core/config/supabase_config.dart';

/// Coarse classification used by the admin queue chips. Maps from the
/// `verification_documents.doc_type` value to a role-scoped audience so
/// reviewers can triage by who-uploaded-what without reading every row.
enum AdminVerificationKind {
  tradeLicence,
  builderAbn,
  whiteCard,
  publicLiability,
  other,
}

AdminVerificationKind _kindForDocType(String docType) => switch (docType) {
  'trade_licence' => AdminVerificationKind.tradeLicence,
  'abn_certificate' => AdminVerificationKind.builderAbn,
  'white_card' => AdminVerificationKind.whiteCard,
  'public_liability' => AdminVerificationKind.publicLiability,
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
    this.verificationId,
    this.capturedLegalName,
    this.capturedEntityType,
    this.gstRegistered,
    this.registerSource,
    this.detailCapturedAt,
    this.abrState,
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

  // STEP 6 curated display projection from the latest matching verifications
  // row, so the admin sees what was captured (and can open the raw receipt).
  final String? verificationId;
  final String? capturedLegalName;
  final String? capturedEntityType;
  final bool? gstRegistered;
  final String? registerSource;
  final DateTime? detailCapturedAt;
  final String? abrState;

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

  /// Items after the active chip filter, triage-sorted (U4.2): pending
  /// oldest-first — the 24 h SLA makes the oldest doc the most urgent —
  /// then reviewed history newest-first.
  List<AdminVerificationItem> get filteredItems {
    final filtered = filter == _filterAll
        ? List<AdminVerificationItem>.of(items)
        : items.where((i) => i.kind == _kindFor(filter)).toList();
    filtered.sort((a, b) {
      final aPending = a.status == 'pending';
      final bPending = b.status == 'pending';
      if (aPending != bPending) return aPending ? -1 : 1;
      return aPending
          ? a.submittedAt.compareTo(b.submittedAt) // oldest pending first
          : b.submittedAt.compareTo(a.submittedAt); // newest reviewed first
    });
    return filtered;
  }

  int countFor(AdminVerificationKindFilter f) => f == _filterAll
      ? items.length
      : items.where((i) => i.kind == _kindFor(f)).length;

  static const _filterAll = AdminVerificationKindFilter.all;

  // Each non-"all" filter maps 1:1 to a row kind.
  static AdminVerificationKind _kindFor(
    AdminVerificationKindFilter f,
  ) => switch (f) {
    AdminVerificationKindFilter.all => AdminVerificationKind.other,
    AdminVerificationKindFilter.tradeLicence =>
      AdminVerificationKind.tradeLicence,
    AdminVerificationKindFilter.builderAbn => AdminVerificationKind.builderAbn,
    AdminVerificationKindFilter.whiteCard => AdminVerificationKind.whiteCard,
    AdminVerificationKindFilter.publicLiability =>
      AdminVerificationKind.publicLiability,
    AdminVerificationKindFilter.other => AdminVerificationKind.other,
  };
}

enum AdminVerificationKindFilter {
  all,
  tradeLicence,
  builderAbn,
  whiteCard,
  publicLiability,
  other,
}

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
                  .select(
                    'id, user_id, kind, status, failure_reason, updated_at, '
                    'abn_entity_name, entity_type, gst_registered, '
                    'register_source, detail_captured_at, abr_state',
                  )
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
    DateTime? parseOptDate(Object? v) =>
        v == null ? null : DateTime.parse(v as String).toLocal();
    // `doc_type`, `file_path`, `submitted_at` were added as NULLABLE columns
    // in 20260516000001_schema_reconciliation. Legacy rows (and rows from any
    // future insert path that forgets to set them) have NULL there — mirror
    // the mobile model's fallbacks instead of blowing up the whole queue.
    final tradeId = row['trade_id'] as String;
    final docType =
        (row['doc_type'] as String?) ?? (row['type'] as String?) ?? 'other';
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
    final submittedRaw = row['submitted_at'] ?? row['created_at'];
    return AdminVerificationItem(
      id: row['id'] as String,
      tradeId: tradeId,
      docType: docType,
      kind: kind,
      status: (row['status'] as String?) ?? 'pending',
      submittedAt: parseOptDate(submittedRaw) ?? DateTime.now().toLocal(),
      filePath: (row['file_path'] as String?) ?? (row['url'] as String?) ?? '',
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
      verificationId: lastVerif?['id'] as String?,
      capturedLegalName: lastVerif?['abn_entity_name'] as String?,
      capturedEntityType: lastVerif?['entity_type'] as String?,
      gstRegistered: lastVerif?['gst_registered'] as bool?,
      registerSource: lastVerif?['register_source'] as String?,
      detailCapturedAt: parseOptDate(lastVerif?['detail_captured_at']),
      abrState: lastVerif?['abr_state'] as String?,
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
    String? confirmedNumber,
    String? tradeClass,
  }) async {
    // Atomic review via SECURITY DEFINER RPC: updates the document AND, on
    // approval of a licence/abn doc, upserts the verified `verifications` row
    // (verifications is service-role-write-only, so a direct admin UPDATE can't
    // reach it). The RPC also writes an admin_actions audit row. See
    // 20260530000003_review_verification_document.sql.
    //
    // p_confirmed_number / p_trade_class let the reviewer record what they
    // actually saw on the document image instead of trusting the user-typed
    // identifier (audit A2). They're only meaningful on approval; pass null on
    // reject so the RPC keeps the typed value untouched on a no-op.
    final trimmed = notes?.trim();
    final isApprove = status == 'approved';
    final number = confirmedNumber?.trim();
    final tradeClassTrimmed = tradeClass?.trim();
    await _client.rpc(
      'review_verification_document',
      params: {
        'p_document_id': id,
        'p_status': status,
        'p_notes': (trimmed != null && trimmed.isNotEmpty) ? trimmed : null,
        'p_confirmed_number': (isApprove && number != null && number.isNotEmpty)
            ? number
            : null,
        'p_trade_class':
            (isApprove &&
                tradeClassTrimmed != null &&
                tradeClassTrimmed.isNotEmpty)
            ? tradeClassTrimmed
            : null,
      },
    );
    await refresh();
  }

  /// Clears a user's currently-verified row of [kind] (`'abn'` | `'licence'`)
  /// via the SECURITY DEFINER `revoke_verification` RPC (verifications is
  /// service-role-write-only). Used when a wrongly-verified identifier or
  /// licence must be undone — the app has no self-service un-verify (audit B4).
  Future<void> revoke({
    required String userId,
    required String kind,
    required String reason,
  }) async {
    await _client.rpc(
      'revoke_verification',
      params: {'p_user_id': userId, 'p_kind': kind, 'p_reason': reason},
    );
    await refresh();
  }

  /// Time-limited signed URL so the admin web app can render a private file.
  /// 60s — long enough to load + view, short enough not to leak.
  Future<String> signedUrl(String filePath) async {
    return _client.storage.from('private-docs').createSignedUrl(filePath, 60);
  }

  /// Audited read of the raw regulator payload. The RPC writes an admin_actions
  /// row before returning verification_events.raw_response (admin-only). See
  /// 20260530000004_admin_view_verification_raw.sql.
  Future<Map<String, dynamic>?> viewRaw(String verificationId) async {
    final res = await _client.rpc(
      'admin_view_verification_raw',
      params: {'p_verification_id': verificationId},
    );
    return res is Map<String, dynamic> ? res : null;
  }
}
