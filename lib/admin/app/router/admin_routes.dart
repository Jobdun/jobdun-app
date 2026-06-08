class AdminRoutes {
  const AdminRoutes._();

  static const String login = '/login';
  static const String dashboard = '/';
  static const String verifications = '/verifications';
  static const String users = '/users';
  static const String jobs = '/jobs';
  static const String audit = '/audit';
  // Admin broadcast — compose a push + in-app announcement (push program
  // Stream A). Took over the former REPORTS roadmap slot in the shell nav.
  static const String broadcast = '/broadcast';
  // Stage 1 roadmap placeholder surface (see STAGE1_COMPLETION_PLAN.md).
  static const String payments = '/payments';

  static String userDetail(String id) => '/users/$id';
  static String jobDetail(String id) => '/jobs/$id';
}
