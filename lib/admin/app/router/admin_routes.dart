class AdminRoutes {
  const AdminRoutes._();

  static const String login = '/login';
  static const String dashboard = '/';
  static const String verifications = '/verifications';
  static const String users = '/users';
  static const String jobs = '/jobs';
  static const String audit = '/audit';
  // Stage 1 roadmap placeholder surfaces (see STAGE1_COMPLETION_PLAN.md).
  static const String reports = '/reports';
  static const String payments = '/payments';

  static String userDetail(String id) => '/users/$id';
  static String jobDetail(String id) => '/jobs/$id';
}
