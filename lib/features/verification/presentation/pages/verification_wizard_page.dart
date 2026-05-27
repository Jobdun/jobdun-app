import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification.dart';
import '../providers/verifications_provider.dart';
import '../widgets/manual_upload_sheet.dart';
import '../widgets/wizard_abn_step.dart';
import '../widgets/wizard_intro_step.dart';
import '../widgets/wizard_licence_step.dart';
import '../widgets/wizard_result_screen.dart';

/// Verification wizard, scoped by role:
///
///   Trade   → Choose → Licence entry → Result   (kind = licence)
///   Builder → Choose → ABN entry → ABN confirm → Result   (kind = abn)
///
/// Verification is OPTIONAL (v2 model) — the wizard never blocks anything.
/// `_Step.choose` is the new default entry: two co-equal CTAs (regulator vs.
/// manual upload). Users with an already-verified row for their role pop
/// immediately with a friendly "you're already verified" snackbar rather
/// than landing on an empty result screen.
class VerificationWizardPage extends ConsumerStatefulWidget {
  const VerificationWizardPage({super.key});

  @override
  ConsumerState<VerificationWizardPage> createState() =>
      _VerificationWizardPageState();
}

enum _Step { choose, abn, licence, result }

class _VerificationWizardPageState
    extends ConsumerState<VerificationWizardPage> {
  _Step _step = _Step.choose;
  VerifyResult? _abnResult;
  VerifyResult? _licenceResult;
  String? _abn;
  String? _licenceNumber;
  String? _licenceState;
  String? _licenceTradeClass;
  bool _initialised = false;

  // Wizard requires an authenticated user. Default to builder if the role
  // is transiently null so the ABN flow loads (matches pre-v2 behavior).
  UserRole get _role =>
      ref.read(authControllerProvider).role ?? UserRole.builder;

  void _maybeShortCircuit(List<Verification> rows) {
    if (_initialised) return;
    _initialised = true;
    final kind = _role == UserRole.trade
        ? VerificationKind.licence
        : VerificationKind.abn;
    final alreadyVerified = rows.any((v) => v.kind == kind && v.isVerified);
    if (!alreadyVerified) return;
    // Defer to next frame so we don't pop / show a snackbar mid-build.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: const Text("You're already verified."),
          duration: const Duration(seconds: 2),
        ),
      );
      context.pop();
    });
  }

  void _onChooseAutomatic() {
    setState(() {
      _step = _role == UserRole.trade ? _Step.licence : _Step.abn;
    });
  }

  Future<void> _onChooseManual() async {
    final docType = _role == UserRole.trade
        ? ManualDocKind.tradeLicence
        : ManualDocKind.abnCertificate;
    final submitted = await showManualUploadSheet(
      context: context,
      kind: docType,
    );
    if (!mounted) return;
    if (submitted) {
      final userId = ref.read(currentUserIdSyncProvider);
      if (userId != null) {
        ref.invalidate(verificationsForUserProvider(userId));
      }
      context.pop();
    }
  }

  void _onAbnSuccess({required String abn, required VerifyResult result}) {
    setState(() {
      _abn = abn;
      _abnResult = result;
      _step = _Step.result;
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
    final userId = ref.read(currentUserIdSyncProvider);
    if (userId != null) {
      ref.invalidate(verificationsForUserProvider(userId));
    }
    if (mounted) context.pop();
  }

  void _onBackToChoose() {
    setState(() => _step = _Step.choose);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // Short-circuit when the user is already verified for their role's kind.
    final myVerifs = ref.watch(myVerificationsProvider);
    myVerifs.whenData(_maybeShortCircuit);

    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        title: const Text('Verification'),
        leading: IconButton(
          icon: Icon(_step == _Step.choose ? Icons.close : Icons.arrow_back),
          tooltip: _step == _Step.choose ? 'Cancel' : 'Back',
          onPressed: () {
            if (_step == _Step.choose || _step == _Step.result) {
              context.pop();
            } else {
              _onBackToChoose();
            }
          },
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
      case _Step.choose:
        return WizardIntroStep(
          role: _role,
          onChooseAutomatic: _onChooseAutomatic,
          onChooseManual: _onChooseManual,
        );
      case _Step.abn:
        return WizardAbnStep(
          stepLabel: 'Automatic check',
          onSuccess: _onAbnSuccess,
        );
      case _Step.licence:
        return WizardLicenceStep(
          stepLabel: 'Automatic check',
          onDone: _onLicenceDone,
          onSkip: () => setState(() => _step = _Step.result),
        );
      case _Step.result:
        return WizardResultScreen(
          role: _role,
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
