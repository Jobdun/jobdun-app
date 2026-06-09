import 'package:equatable/equatable.dart';

// Matches schema enum public.quote_request_status exactly.
enum QuoteRequestStatus { requested, quoted, declined, accepted, withdrawn }

extension QuoteRequestStatusX on QuoteRequestStatus {
  String get label => switch (this) {
    QuoteRequestStatus.requested => 'Requested',
    QuoteRequestStatus.quoted => 'Quoted',
    QuoteRequestStatus.declined => 'Declined',
    QuoteRequestStatus.accepted => 'Accepted',
    QuoteRequestStatus.withdrawn => 'Withdrawn',
  };

  String get dbValue => name;

  static QuoteRequestStatus fromDb(String v) =>
      QuoteRequestStatus.values.firstWhere(
        (s) => s.name == v,
        orElse: () => QuoteRequestStatus.requested,
      );
}

/// A builder's standalone request for a quote from a specific trade on a job
/// (#18). Distinct from the trade-initiated `quote_amount` on an application.
class QuoteRequest extends Equatable {
  const QuoteRequest({
    required this.id,
    required this.jobId,
    required this.builderId,
    required this.tradeId,
    required this.status,
    required this.createdAt,
    this.requestNote,
    this.quoteAmount,
    this.responseNote,
    this.respondedAt,
    // Joined for the trade inbox.
    this.jobTitle,
    this.builderCompanyName,
    // Joined for the builder view.
    this.tradeFullName,
    this.tradePrimaryTrade,
  });

  final String id;
  final String jobId;
  final String builderId;
  final String tradeId;
  final QuoteRequestStatus status;
  final String? requestNote;
  // The trade's reply, in dollars. Null until they respond.
  final double? quoteAmount;
  final String? responseNote;
  final DateTime createdAt;
  final DateTime? respondedAt;

  // Joined from jobs (both views).
  final String? jobTitle;
  // Joined from builder_profiles (trade inbox — who's asking).
  final String? builderCompanyName;
  // Joined from trade_profiles (builder view — who was asked).
  final String? tradeFullName;
  final String? tradePrimaryTrade;

  /// Awaiting the trade's response — the only state the trade can act on.
  bool get isAwaitingResponse => status == QuoteRequestStatus.requested;

  @override
  List<Object?> get props => [id, jobId, tradeId, status, quoteAmount];
}
