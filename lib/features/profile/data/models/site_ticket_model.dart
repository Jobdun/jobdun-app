import '../../domain/entities/site_ticket.dart';

class SiteTicketModel extends SiteTicket {
  const SiteTicketModel({
    required super.slug,
    required super.shortName,
    required super.displayName,
    required super.category,
    required super.sortOrder,
    super.docType,
  });

  factory SiteTicketModel.fromJson(Map<String, dynamic> json) =>
      SiteTicketModel(
        slug: json['slug'] as String,
        shortName: json['short_name'] as String,
        displayName: json['display_name'] as String,
        category: SiteTicketCategory.fromDb(json['category'] as String),
        sortOrder: (json['sort_order'] as int?) ?? 0,
        docType: json['doc_type'] as String?,
      );
}
