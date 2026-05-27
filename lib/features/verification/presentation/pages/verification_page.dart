import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';

/// Legacy `/verification` entry. Pre-v2 this page was a trade-only licence
/// upload surface; v2.1 unified everything into `/verification/wizard`, which
/// owns the choose-step (regulator vs. manual upload), the role-scoped wizard
/// kinds, and the manual-upload sheet.
///
/// The route stays so deep links and any cached navigation paths continue to
/// resolve — they just land in the wizard now. Redirect is fired in the next
/// frame so the back-stack ends up with the wizard as the top entry, not a
/// transient `/verification` mid-stack the user could swipe back to.
class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go('/verification/wizard');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: SizedBox.shrink());
  }
}
