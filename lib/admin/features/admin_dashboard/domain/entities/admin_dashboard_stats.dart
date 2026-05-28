import 'package:equatable/equatable.dart';

class AdminDashboardStats extends Equatable {
  const AdminDashboardStats({
    required this.totalUsers,
    required this.pendingVerifications,
    required this.openJobs,
    required this.rejectedLast7Days,
  });

  final int totalUsers;
  final int pendingVerifications;
  final int openJobs;
  final int rejectedLast7Days;

  @override
  List<Object?> get props => [
    totalUsers,
    pendingVerifications,
    openJobs,
    rejectedLast7Days,
  ];
}
