import '../../domain/entities/verification_document.dart';

/// Credential kinds a user can submit through the manual-upload sheet.
///
/// `abnCertificate` is the builder's fallback; the other three are the trade
/// trust-layer: a licence, a White Card (construction induction), and public
/// liability insurance. Every kind lands in `verification_documents` and is
/// confirmed by a human reviewer — there is no automated check
/// (`AUTO_VERIFY_ENABLED` stays false), so all surfaces say "reviewed by a
/// person", never "checked against a regulator".
///
/// Each kind declares which fields the sheet must capture. Keep these getters
/// total — adding a value forces every dependent surface (the sheet, the form,
/// the receipts card) to decide how it behaves.
enum ManualDocKind { abnCertificate, tradeLicence, whiteCard, publicLiability }

extension ManualDocKindX on ManualDocKind {
  DocType get docType => switch (this) {
    ManualDocKind.abnCertificate => DocType.abnCertificate,
    ManualDocKind.tradeLicence => DocType.tradeLicence,
    ManualDocKind.whiteCard => DocType.whiteCard,
    ManualDocKind.publicLiability => DocType.publicLiability,
  };

  String get sheetTitle => switch (this) {
    ManualDocKind.abnCertificate => 'Upload your ABN certificate',
    ManualDocKind.tradeLicence => 'Upload your trade licence',
    ManualDocKind.whiteCard => 'Upload your White Card',
    ManualDocKind.publicLiability => 'Upload your insurance',
  };

  String get numberLabel => switch (this) {
    ManualDocKind.abnCertificate => 'ABN',
    ManualDocKind.tradeLicence => 'Licence number',
    ManualDocKind.whiteCard => 'Card number',
    ManualDocKind.publicLiability => 'Policy number',
  };

  String get numberHint => switch (this) {
    ManualDocKind.abnCertificate => '11 digits',
    ManualDocKind.tradeLicence => 'e.g. EL-12345',
    ManualDocKind.whiteCard => 'e.g. WC-123456',
    ManualDocKind.publicLiability => 'e.g. PL-987654',
  };

  /// True for credentials issued per-jurisdiction: a trade licence (state
  /// regulator) and a White Card (state RTO / SafeWork). ABN is national;
  /// public liability is insurer-issued (captured via [requiresIssuer]).
  bool get requiresState =>
      this == ManualDocKind.tradeLicence || this == ManualDocKind.whiteCard;

  /// True for the licence only — White Card / insurance / ABN are not filed
  /// under a trade class. Distinct from [requiresState] because a White Card
  /// has a state but no class.
  bool get requiresTradeClass => this == ManualDocKind.tradeLicence;

  /// Everything except an ABN lapses, so it must capture an expiry date.
  bool get requiresExpiry => this != ManualDocKind.abnCertificate;

  /// Only public liability captures a free-text insurer name. A licence /
  /// White Card derive their issuer from the state; an ABN's issuer is fixed
  /// (the Australian Business Register).
  bool get requiresIssuer => this == ManualDocKind.publicLiability;
}
