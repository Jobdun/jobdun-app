import 'package:equatable/equatable.dart';

import 'verification_document.dart';

/// Minimized, counterparty-visible projection of an APPROVED supplementary
/// credential — a White Card or public-liability policy a tradie has uploaded
/// and a reviewer has approved.
///
/// Sourced from the `get_trade_public_credentials` RPC, which only ever returns
/// approved docs, so the presence of an instance means "a reviewer approved
/// this". It never carries the document URL, the policy/card number, the
/// insurer, the state, or review notes — those stay owner/admin-only behind the
/// `verification_documents` owner-RLS. Mirrors [BuilderPublicVerification], the
/// equivalent register-derived badge for ABN/licence.
class TradePublicCredential extends Equatable {
  const TradePublicCredential({
    required this.userId,
    required this.docType,
    this.expiresAt,
    this.isExpired = false,
    this.capturedAt,
  });

  final String userId;

  /// `whiteCard` or `publicLiability` — the only supplementary kinds the RPC
  /// projects. Other doc types stay owner-only.
  final DocType docType;

  /// When the credential lapses. Display-only ("expires d MMM yyyy").
  final DateTime? expiresAt;

  /// Whether the credential has lapsed. Derived server-side ('current' vs
  /// 'expired') so client clock-skew can never flip the badge.
  final bool isExpired;

  /// The "as at" approval timestamp — render alongside the badge so a stale
  /// approval can't read as a bare "verified".
  final DateTime? capturedAt;

  /// U5: true when the credential lapses within 30 days of [now] — drives the
  /// owner-side "upload a renewal" nudge. Counterparty surfaces ignore this
  /// (the public signal must not degrade before it actually expires).
  bool expiresSoonAt(DateTime now) =>
      !isExpired &&
      expiresAt != null &&
      !expiresAt!.isBefore(now) &&
      expiresAt!.difference(now) <= const Duration(days: 30);

  /// Convenience over [expiresSoonAt] with the real clock.
  bool get expiresSoon => expiresSoonAt(DateTime.now());

  @override
  List<Object?> get props => [
    userId,
    docType,
    expiresAt,
    isExpired,
    capturedAt,
  ];
}
