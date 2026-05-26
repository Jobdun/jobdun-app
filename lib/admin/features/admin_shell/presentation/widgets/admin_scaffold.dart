import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import 'admin_sidebar.dart';
import 'admin_topbar.dart';

/// Two-column desktop chrome — sidebar on the left, topbar + content on the
/// right. Pages compose this around their content so navigation is consistent
/// across the admin app.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.activeRoute,
    required this.child,
    this.trailing,
  });

  final String title;
  final String activeRoute;
  final Widget child;
  final List<Widget>? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSidebar(activeRoute: activeRoute),
          Expanded(
            child: Column(
              children: [
                AdminTopbar(title: title, trailing: trailing),
                Expanded(
                  child: Container(
                    color: c.background,
                    padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
