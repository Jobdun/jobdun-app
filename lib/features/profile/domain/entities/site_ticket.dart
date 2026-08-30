import 'package:equatable/equatable.dart';

/// Grouping for the section headers in the tickets sheet.
enum SiteTicketCategory {
  induction,
  safety,
  licence,
  transport;

  String get dbValue => switch (this) {
    SiteTicketCategory.induction => 'induction',
    SiteTicketCategory.safety => 'safety',
    SiteTicketCategory.licence => 'licence',
    SiteTicketCategory.transport => 'transport',
  };

  String get label => switch (this) {
    SiteTicketCategory.induction => 'Induction',
    SiteTicketCategory.safety => 'Safety',
    SiteTicketCategory.licence => 'Licences',
    SiteTicketCategory.transport => 'Transport',
  };

  /// Unknown values fall back rather than throw. `site_tickets` is editable
  /// from the dashboard without an app release, so a category added tomorrow
  /// must not crash a build shipped today. Safety is the conservative bucket.
  static SiteTicketCategory fromDb(String value) => switch (value) {
    'induction' => SiteTicketCategory.induction,
    'safety' => SiteTicketCategory.safety,
    'licence' => SiteTicketCategory.licence,
    'transport' => SiteTicketCategory.transport,
    _ => SiteTicketCategory.safety,
  };
}

/// Reference data — a row in `public.site_tickets`. Read-only on the client.
///
/// [docType] links the ticket to the `verification_documents` review path.
/// Null means there is no review path yet, so the ticket can only ever be
/// self-declared and the "upload to verify" nudge MUST NOT render for it —
/// offering a verification route that does not exist is a dead-end tap.
class SiteTicket extends Equatable {
  const SiteTicket({
    required this.slug,
    required this.shortName,
    required this.displayName,
    required this.category,
    required this.sortOrder,
    this.docType,
  });

  final String slug;

  /// Chip label, e.g. "EWP Licence (WP)".
  final String shortName;

  /// Full name with the unit code, e.g. "Working at Heights (RIIWHS204E)".
  final String displayName;

  final SiteTicketCategory category;
  final int sortOrder;
  final String? docType;

  bool get isVerifiable => docType != null && docType!.isNotEmpty;

  @override
  List<Object?> get props => [
    slug,
    shortName,
    displayName,
    category,
    sortOrder,
    docType,
  ];
}
