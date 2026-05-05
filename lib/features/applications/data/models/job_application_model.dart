import '../../domain/entities/job_application.dart';

class JobApplicationModel extends JobApplication {
  const JobApplicationModel({
    required super.id,
    required super.jobId,
    required super.tradeId,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.coverMessage,
  });

  factory JobApplicationModel.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    final status = ApplicationStatus.values.firstWhere(
      (s) => s.name == statusStr,
      orElse: () => ApplicationStatus.pending,
    );
    return JobApplicationModel(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      tradeId: json['trade_id'] as String,
      status: status,
      coverMessage: json['cover_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'job_id': jobId,
    'trade_id': tradeId,
    'status': status.name,
    'cover_message': coverMessage,
  };
}
