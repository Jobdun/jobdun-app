/// Pure mapping + predicate helpers shared by the admin review UI.
///
/// The admin queue projects `verification_documents.doc_type` into the queue,
/// but the `verifications`/revoke RPCs speak the coarser `kind` vocabulary
/// (`'abn'` | `'licence'`). These helpers are the single, testable seam between
/// the two — no Flutter/Supabase imports, so the logic can be unit-tested
/// without a widget or a client.
library;

/// Maps a `verification_documents.doc_type` to the `verifications.kind` value
/// used by the revoke / review RPCs. Returns null for doc types that don't map
/// to a verifiable identity row (e.g. white card, photo ID, insurance).
String? docTypeToVerificationKind(String docType) => switch (docType) {
  'trade_licence' => 'licence',
  'abn_certificate' => 'abn',
  _ => null,
};

/// Whether a "Revoke verification" action should be offered for this item.
///
/// True only when the user currently holds a *verified* row of a revocable
/// kind — i.e. the latest matching `verifications` row is `status='verified'`
/// AND the doc type maps to a real kind. A pending/rejected/expired row, or a
/// non-verifiable doc type, has nothing to revoke.
bool canRevokeVerification({
  required String docType,
  required String? lastVerificationStatus,
}) =>
    lastVerificationStatus == 'verified' &&
    docTypeToVerificationKind(docType) != null;
