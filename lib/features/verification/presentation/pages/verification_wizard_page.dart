import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification.dart';
import '../providers/verifications_provider.dart';
import '../widgets/wizard_abn_step.dart';
import '../widgets/wizard_licence_step.dart';
import '../widgets/wizard_result_screen.dart';

/// Multi-step verification wizard. Single scaffold for both roles; the step
/// list is resolved from the current user's [UserRole].
///
///   Trade   → ABN entry → ABN confirm → Licence entry (skippable) → Result
///   Builder → ABN entry → ABN confirm → Result (no licence)
///
/// Verification is OPTIONAL (v2 model) — the wizard never blocks anything.
/// Tapping back / hardware back / Cancel at any step leaves the wizard
/// cleanly; the home banner brings the user back later.
class VerificationWizardPage extends ConsumerStatefulWidget {
  const VerificationWizardPage({super.key});

  @override
  ConsumerState<VerificationWizardPage> createState() =>
      _VerificationWizardPageState();
}

enum _Step { abn, licence, result }

class _VerificationWizardPageState
    extends ConsumerState<VerificationWizardPage> {
  _Step _step = _Step.abn;
  VerifyResult? _abnResult;
  VerifyResult? _licenceResult;
  String? _abn;
  String? _licenceNumber;
  String? _licenceState;
  String? _licenceTradeClass;

  bool get _isTrade => ref.read(authControllerProvider).role == UserRole.trade;

  void _onAbnSuccess({required String abn, required VerifyResult result}) {
    setState(() {
      _abn = abn;
      _abnResult = result;
      _step = _isTrade ? _Step.licence : _Step.result;
    });
  }

  void _onLicenceDone({
    String? licenceNumber,
    String? state,
    String? tradeClass,
    VerifyResult? result,
  }) {
    setState(() {
      _licenceNumber = licenceNumber;
      _licenceState = state;
      _licenceTradeClass = tradeClass;
      _licenceResult = result;
      _step = _Step.result;
    });
  }

  Future<void> _onFinish() async {
    // Refresh provider so receipts panel updates everywhere.
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId != null) {
      ref.invalidate(verificationsForUserProvider(userId));
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Verification'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          child: _buildStep(),
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case _Step.abn:
        return WizardAbnStep(
          stepLabel: _isTrade ? 'Step 1 of 2' : 'Step 1 of 1',
          onSuccess: _onAbnSuccess,
        );
      case _Step.licence:
        return WizardLicenceStep(
          stepLabel: 'Step 2 of 2',
          onDone: _onLicenceDone,
          onSkip: () => setState(() => _step = _Step.result),
        );
      case _Step.result:
        return WizardResultScreen(
          abnResult: _abnResult,
          licenceResult: _licenceResult,
          abn: _abn,
          licenceNumber: _licenceNumber,
          licenceState: _licenceState,
          licenceTradeClass: _licenceTradeClass,
          onFinish: _onFinish,
        );
    }
  }
}
