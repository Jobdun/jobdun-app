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
/// frame with `pushReplacement` (NOT `go`): `go` discarded the stack the user
/// arrived with, so closing the wizard stranded them on this blank shim with
/// nothing left to pop (live bug, 2026-08-18 audit — "the licence area came
/// up blank"). Replacing just this entry keeps the caller's stack intact.
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
      context.pushReplacement('/verification/wizard');
    });
  }

  @override
  Widget build(BuildContext context) {
    // Never a bare blank screen: if the redirect is ever interrupted the
    // user still has an AppBar with a working back affordance.
    return Scaffold(appBar: AppBar(title: const Text('Verification')));
  }
}
