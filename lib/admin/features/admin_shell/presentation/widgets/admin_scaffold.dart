import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import 'admin_sidebar.dart';
import 'admin_topbar.dart';

/// Below this viewport width the sidebar auto-collapses to its rail. Picked
/// to keep at least 800px of content area when the sidebar is expanded
/// (1024 - 240 = 784).
const double _autoCollapseBreakpoint = 1024;

/// Two-column desktop chrome — sidebar on the left, topbar + content on the
/// right. Pages compose this around their content so navigation is consistent
/// across the admin app.
///
/// Owns the sidebar collapsed state. Default behaviour follows the viewport
/// (auto-collapse < 1024 px). Once the user toggles, their preference takes
/// over until they toggle again.
class AdminScaffold extends StatefulWidget {
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
  State<AdminScaffold> createState() => _AdminScaffoldState();
}

class _AdminScaffoldState extends State<AdminScaffold> {
  /// `null` → follow the viewport breakpoint.
  /// `true`/`false` → user has explicitly chosen a state.
  bool? _userCollapsed;

  bool _autoCollapsed(BuildContext context) =>
      MediaQuery.sizeOf(context).width < _autoCollapseBreakpoint;

  void _handleToggle() {
    final current = _userCollapsed ?? _autoCollapsed(context);
    setState(() => _userCollapsed = !current);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final collapsed = _userCollapsed ?? _autoCollapsed(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminSidebar(
            activeRoute: widget.activeRoute,
            collapsed: collapsed,
            onToggle: _handleToggle,
          ),
          Expanded(
            child: Column(
              children: [
                AdminTopbar(title: widget.title, trailing: widget.trailing),
                Expanded(
                  child: Container(
                    color: c.background,
                    padding: const EdgeInsets.fromLTRB(40, 32, 40, 40),
                    child: widget.child,
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
