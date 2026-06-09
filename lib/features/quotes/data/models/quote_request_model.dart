import '../../domain/entities/quote_request.dart';

class QuoteRequestModel extends QuoteRequest {
  const QuoteRequestModel({
    required super.id,
    required super.jobId,
    required super.builderId,
    required super.tradeId,
    required super.status,
    required super.createdAt,
    super.requestNote,
    super.quoteAmount,
    super.responseNote,
    super.respondedAt,
    super.jobTitle,
    super.builderCompanyName,
    super.tradeFullName,
    super.tradePrimaryTrade,
  });

  factory QuoteRequestModel.fromJson(Map<String, dynamic> json) {
    final job = json['jobs'] as Map<String, dynamic>?;
    final builder = json['builder_profiles'] as Map<String, dynamic>?;
    final trade = json['trade_profiles'] as Map<String, dynamic>?;
    return QuoteRequestModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      builderId: json['builder_id'] as String,
      tradeId: json['trade_id'] as String,
      status: QuoteRequestStatusX.fromDb(
        json['status'] as String? ?? 'requested',
      ),
      requestNote: json['request_note'] as String?,
      quoteAmount: (json['quote_amount'] as num?)?.toDouble(),
      responseNote: json['response_note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      respondedAt: json['responded_at'] != null
          ? DateTime.parse(json['responded_at'] as String).toLocal()
          : null,
      jobTitle: job?['title'] as String?,
      builderCompanyName: builder?['company_name'] as String?,
      tradeFullName: trade?['full_name'] as String?,
      tradePrimaryTrade: trade?['primary_trade'] as String?,
    );
  }
}
