import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart' as docs;
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';
import '../widgets/manual_upload_sheet.dart';
import '../widgets/wizard_abn_step.dart';
import '../widgets/wizard_intro_step.dart';
import '../widgets/wizard_licence_step.dart';
import '../widgets/wizard_result_screen.dart';

/// Verification wizard, scoped by role:
///
///   Trade   → manual upload sheet directly (kind = licence)
///   Builder → Choose → ABN entry → ABN confirm → Result   (kind = abn)
///
/// Verification is OPTIONAL (v2 model) — the wizard never blocks anything.
///
/// Manual-only routing for trades (2026-05-29): the licence auto-path is
/// disabled until a real state-regulator adapter ships (see
/// `wizard_licence_step.dart` `_supportedStates`), so for trades the intro
/// step would offer a single useful CTA — that's a pointless gate. Trades
/// skip straight to the manual upload sheet; the priming the intro used to
/// carry is now baked into the sheet itself (`ManualUploadPrimingBlock`).
/// Builders keep the choose-then-ABN-then-result flow because their auto
/// path against the Australian Business Register is live.
///
/// Users with an already-verified row for their role pop immediately with a
/// friendly "you're already verified" snackbar rather than landing on an
/// empty result screen — UNLESS [reverify] is set (the "Re-verify →" CTA),
/// in which case the short-circuit is bypassed so they can redo the check.
class VerificationWizardPage extends ConsumerStatefulWidget {
  const VerificationWizardPage({super.key, this.reverify = false});

  /// True when entered via `/verification/wizard?reverify=1`. Lets an
  /// already-verified user redo their check instead of being popped out (B3).
  final bool reverify;

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

  // Wizard requires an authenticated user. The role can be transiently null
  // while the JWT/DB resolve — F1: we must NOT default to builder, or a trade
  // briefly gets the ABN screen. Returns null until the role is actually known
  // (`isRoleLoaded` AND a non-null role); the build shows a spinner meanwhile.
  UserRole? get _resolvedRole {
    final auth = ref.read(authControllerProvider);
    return auth.isRoleLoaded ? auth.role : null;
  }

  void _maybeShortCircuit(List<Verification> rows) {
    if (_initialised) return;
    final role = _resolvedRole;
    // F1: don't branch until the role is known — wait for a later rebuild.
    if (role == null) return;
    _initialised = true;
    final kind = role == UserRole.trade
        ? VerificationKind.licence
        : VerificationKind.abn;
    final alreadyVerified = rows.any((v) => v.kind == kind && v.isVerified);
    // B3: in reverify mode an already-verified row is the whole point — let
    // the user redo the check instead of popping them straight back out.
    if (alreadyVerified && !widget.reverify) {
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
      return;
    }
    // Trades bypass the intro entirely — the only real action is manual
    // upload (auto-path is disabled until regulator adapters ship). Open
    // the sheet on the first frame, then pop the wizard whether the user
    // submits or cancels — there's nothing else on this page for them.
    if (role == UserRole.trade) {
      // B5: don't open a second upload sheet over an existing pending doc —
      // the reviewer already has one in the queue. Skip the guard in reverify
      // mode (the user explicitly chose to redo).
      if (!widget.reverify && _hasPendingDoc(docs.DocType.tradeLicence)) {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showUnderReview();
          context.pop();
        });
        return;
      }
      SchedulerBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final submitted = await showManualUploadSheet(
          context: context,
          kind: ManualDocKind.tradeLicence,
        );
        if (!mounted) return;
        if (submitted) {
          final userId = ref.read(currentUserIdSyncProvider);
          if (userId != null) {
            ref.invalidate(verificationsForUserProvider(userId));
          }
        }
        context.pop();
      });
    }
  }

  // B5: true when the user already has a pending (not-yet-reviewed) upload of
  // this type. Reads the realtime-backed documents list off the controller.
  bool _hasPendingDoc(docs.DocType docType) {
    final documents = ref.read(verificationControllerProvider).documents;
    return documents.any(
      (d) =>
          d.docType == docType && d.status == docs.VerificationStatus.pending,
    );
  }

  void _showUnderReview() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text(
          'Already under review — a reviewer will confirm within 24 h.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _onChooseAutomatic() {
    // Only reachable from WizardIntroStep, which renders for builders only
    // (role already resolved). Default to builder defensively.
    setState(() {
      _step = _resolvedRole == UserRole.trade ? _Step.licence : _Step.abn;
    });
  }

  Future<void> _onChooseManual() async {
    final docType = _resolvedRole == UserRole.trade
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
    // Watch role-loaded so the build re-runs (and the short-circuit fires)
    // once the role resolves — F1: until then we render a spinner, never the
    // builder ABN flow by default.
    final roleLoaded = ref.watch(
      authControllerProvider.select((s) => s.isRoleLoaded),
    );
    final role = _resolvedRole;
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
          child: (!roleLoaded || role == null)
              ? const Center(child: CircularProgressIndicator())
              : _buildStep(role),
        ),
      ),
    );
  }

  Widget _buildStep(UserRole role) {
    switch (_step) {
      case _Step.choose:
        // Trades never see the intro — the first frame fires
        // `_maybeShortCircuit` which opens the manual sheet directly.
        // Show a neutral spinner for that single frame so we don't flash
        // the dead-end choose cards before the sheet overlays them.
        if (role == UserRole.trade) {
          return const Center(child: CircularProgressIndicator());
        }
        return WizardIntroStep(
          role: role,
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
          role: role,
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
