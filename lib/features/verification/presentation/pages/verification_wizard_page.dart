import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/providers/current_user_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../domain/entities/verification.dart';
import '../../domain/entities/verification_document.dart' as docs;
import '../providers/verification_provider.dart';
import '../providers/verifications_provider.dart';
import '../widgets/manual_upload_sheet.dart';
import '../widgets/trust_chip.dart';
import '../widgets/verification_receipts.dart';
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
    // Trades land on the "Your credentials" list (licence + White Card +
    // public liability) — no short-circuit, no auto-opened sheet. Each row
    // owns its own upload CTA, and an already-verified / under-review state is
    // shown inline by the receipts card.
    if (role == UserRole.trade) return;
    // Builder: an already-verified ABN pops straight back out (unless the user
    // explicitly chose to re-verify — B3).
    final alreadyVerified = rows.any(
      (v) => v.kind == VerificationKind.abn && v.isVerified,
    );
    if (alreadyVerified && !widget.reverify) {
      // Defer to next frame so we don't pop / show a snackbar mid-build.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text("You're already verified."),
            duration: Duration(seconds: 2),
          ),
        );
        context.pop();
      });
    }
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
        // U3.4: trades land on a credentials hub, not a wizard — name it so.
        // One title per screen: the hub body's H1 carries the full phrase.
        title: Text(role == UserRole.trade ? 'Credentials' : 'Verification'),
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
              ? const _RoleResolvingSkeleton()
              : _buildStep(role),
        ),
      ),
    );
  }

  Widget _buildStep(UserRole role) {
    switch (_step) {
      case _Step.choose:
        // Trades land on the "Your credentials" list — licence + White Card +
        // public liability, each with its own upload CTA. Builders keep the
        // ABN choose-then-verify intro (their ABR auto-path is live).
        if (role == UserRole.trade) {
          return _TradeCredentialsStep(
            userId: ref.read(currentUserIdSyncProvider) ?? '',
          );
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

/// Trade verification landing — a "Your credentials" hub. Reuses
/// [VerificationReceipts] (the same card shown on the profile) so the licence /
/// White Card / public-liability rows and their per-row upload CTAs stay a
/// single source of truth. Manual review only; nothing here blocks apply/hire.
///
/// U3.3: leads with the payoff — a "How builders see you" strip rendering the
/// exact [TrustChip]s a builder gets (approved creds verified, the rest as
/// ghost placeholders) plus an N OF 3 progress eyebrow, so the upload effort
/// has a visible reward before the form asks for anything.
class _TradeCredentialsStep extends ConsumerWidget {
  const _TradeCredentialsStep({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final uploaded = ref.watch(verificationControllerProvider).documents;
    final verifs =
        ref.watch(myVerificationsProvider).asData?.value ??
        const <Verification>[];

    bool hasDoc(docs.DocType t, {required bool approvedOnly}) => uploaded.any(
      (d) =>
          d.docType == t &&
          (d.status == docs.VerificationStatus.approved ||
              (!approvedOnly && d.status == docs.VerificationStatus.pending)),
    );
    final licenceVerified =
        verifs.any((v) => v.kind == VerificationKind.licence && v.isVerified) ||
        hasDoc(docs.DocType.tradeLicence, approvedOnly: true);

    // "Added" counts pending too — the user has done their part; the preview
    // chips below stay ghosts until a reviewer approves (caption explains).
    final added = [
      licenceVerified || hasDoc(docs.DocType.tradeLicence, approvedOnly: false),
      hasDoc(docs.DocType.whiteCard, approvedOnly: false),
      hasDoc(docs.DocType.publicLiability, approvedOnly: false),
    ].where((a) => a).length;

    TrustChipState previewState(bool approved) =>
        approved ? TrustChipState.verified : TrustChipState.placeholder;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text('Your credentials', style: tt.headlineMedium),
              ),
              Text(
                '$added OF 3 ADDED',
                style: tt.labelSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: c.text3,
                ),
              ),
            ],
          ),
          Gap(8.h),
          Text(
            'Add any of these so builders can trust your profile. A real person '
            'reviews each upload, usually within 24 hours.',
            style: tt.bodyMedium,
          ),
          Gap(16.h),
          const FieldLabel('HOW BUILDERS SEE YOU'),
          Gap(8.h),
          Wrap(
            spacing: 6.w,
            runSpacing: 6.h,
            children: [
              TrustChip(label: 'Licence', state: previewState(licenceVerified)),
              TrustChip(
                label: 'White Card',
                state: previewState(
                  hasDoc(docs.DocType.whiteCard, approvedOnly: true),
                ),
              ),
              TrustChip(
                label: 'Insured',
                state: previewState(
                  hasDoc(docs.DocType.publicLiability, approvedOnly: true),
                ),
              ),
            ],
          ),
          Gap(6.h),
          Text(
            'Badges appear on your applications the moment a reviewer '
            'approves them.',
            style: tt.bodySmall!.copyWith(color: c.text3),
          ),
          Gap(16.h),
          VerificationReceipts(
            userId: userId,
            isOwner: true,
            showAbnRow: false,
            showLicenceRow: true,
            showWhiteCardRow: true,
            showInsuranceRow: true,
          ),
        ],
      ),
    );
  }
}

/// U3.4: content-shaped placeholder while the JWT role resolves — replaces the
/// bare page-body spinner (MASTER: skeletons for page-body loading).
class _RoleResolvingSkeleton extends StatelessWidget {
  const _RoleResolvingSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget bar({required double width, required double height}) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(4.r),
      ),
    );
    return JSkeletonList(
      enabled: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          bar(width: 220.w, height: 26.h),
          Gap(12.h),
          bar(width: double.infinity, height: 16.h),
          Gap(8.h),
          bar(width: 280.w, height: 16.h),
          Gap(24.h),
          bar(width: double.infinity, height: 72.h),
          Gap(12.h),
          bar(width: double.infinity, height: 72.h),
          Gap(12.h),
          bar(width: double.infinity, height: 72.h),
        ],
      ),
    );
  }
}
