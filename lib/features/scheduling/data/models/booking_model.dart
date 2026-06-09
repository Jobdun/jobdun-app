import '../../domain/entities/booking.dart';

class BookingModel extends Booking {
  const BookingModel({
    required super.id,
    required super.jobId,
    required super.builderId,
    required super.tradeId,
    required super.scheduledDate,
    required super.status,
    required super.createdAt,
    super.note,
    super.jobTitle,
    super.builderCompanyName,
    super.tradeFullName,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    final job = json['jobs'] as Map<String, dynamic>?;
    final builder = json['builder_profiles'] as Map<String, dynamic>?;
    final trade = json['trade_profiles'] as Map<String, dynamic>?;
    final d = DateTime.parse(json['scheduled_date'] as String);
    return BookingModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      builderId: json['builder_id'] as String,
      tradeId: json['trade_id'] as String,
      scheduledDate: DateTime(d.year, d.month, d.day),
      status: BookingStatusX.fromDb(json['status'] as String? ?? 'scheduled'),
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      jobTitle: job?['title'] as String?,
      builderCompanyName: builder?['company_name'] as String?,
      tradeFullName: trade?['full_name'] as String?,
    );
  }
}
