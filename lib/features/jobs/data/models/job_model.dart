import '../../domain/entities/job.dart';

class JobModel extends Job {
  const JobModel({
    required super.id,
    required super.builderId,
    required super.title,
    required super.description,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.location,
    super.budget,
    super.budgetType,
    super.startDate,
    super.tradeCategory,
    super.requiredSkills,
    super.requiredLicences,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) => JobModel(
    id: json['id'] as String,
    builderId: json['builder_id'] as String,
    title: json['title'] as String,
    description: json['description'] as String,
    status: JobStatusX.fromDb(json['status'] as String? ?? 'open'),
    createdAt: DateTime.parse(json['created_at'] as String),
    updatedAt: DateTime.parse(json['updated_at'] as String),
    location: json['location'] as String?,
    budget: (json['budget'] as num?)?.toDouble(),
    budgetType: json['budget_type'] as String? ?? 'fixed',
    startDate: json['start_date'] != null
        ? DateTime.parse(json['start_date'] as String)
        : null,
    tradeCategory: json['trade_category'] as String?,
    requiredSkills:
        (json['required_skills'] as List<dynamic>?)?.cast<String>() ?? [],
    requiredLicences:
        (json['required_licences'] as List<dynamic>?)?.cast<String>() ?? [],
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'builder_id': builderId,
    'title': title,
    'description': description,
    'status': status.dbValue,
    'location': location,
    'budget': budget,
    'budget_type': budgetType,
    'start_date': startDate?.toIso8601String().split('T').first,
    'trade_category': tradeCategory,
    'required_skills': requiredSkills,
    'required_licences': requiredLicences,
  };
}
