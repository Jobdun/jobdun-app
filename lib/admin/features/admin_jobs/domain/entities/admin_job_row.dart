import 'package:equatable/equatable.dart';

class AdminJobRow extends Equatable {
  const AdminJobRow({
    required this.id,
    required this.title,
    required this.status,
    required this.builderDisplayName,
    required this.applicationCount,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status; // draft | open | filled | closed | cancelled
  final String builderDisplayName;
  final int applicationCount;
  final DateTime createdAt;

  @override
  List<Object?> get props => [
        id,
        title,
        status,
        builderDisplayName,
        applicationCount,
        createdAt,
      ];
}
