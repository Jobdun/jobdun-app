part of 'job_detail_page.dart';

// Presentational leaves for the job detail page — split into a `part` so the
// page stays under the file-size budget. Single-use, co-located with the page.

// Tap through to the public builder profile (S13) — company, ABN ✓, track
// record, reviews from tradies — so a tradie can vet who they're applying to
// before they do. Guests hit the account gate instead: profile data is
// served by authenticated-only views.
class _PostedByCard extends StatelessWidget {
  const _PostedByCard({required this.args, required this.isAuthed});

  final JobDetailArgs args;
  final bool isAuthed;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: args.builderId == null
          ? null
          : !isAuthed
          ? () => GuestGateSheet.show(
              context,
              actionCaps: 'SEE BUILDER PROFILES',
              returnTo: args.id == null ? null : '/jobs/${args.id}',
            )
          : () => context.push('/builders/${args.builderId}'),
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40.r,
              height: 40.r,
              decoration: BoxDecoration(
                color: c.surfaceRaised,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
              alignment: Alignment.center,
              child: Text(
                args.builderInitials ?? 'B',
                style: tt.titleLarge!.copyWith(
                  fontWeight: FontWeight.w700,
                  color: c.text2,
                ),
              ),
            ),
            Gap(8.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    args.companyName ?? 'Builder',
                    style: tt.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.0,
                      color: c.text1,
                    ),
                  ),
                  if (args.builderId != null) ...[
                    Gap(4.h),
                    Text(
                      'View profile and Reviews',
                      style: tt.labelMedium!.copyWith(
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0,
                        height: 1.4,
                        // The mock uses the fill orange; at 12dp that is
                        // 3.34:1, so the ink token carries it.
                        color: c.actionInk,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (args.builderId != null)
              Icon(
                AppIcons.chevronRight,
                size: AppIconSize.inline.r,
                color: c.text3,
              ),
          ],
        ),
      ),
    );
  }
}

/// Section heading on Job Details — 16dp Bold, sentence case (Figma node
/// 134:13365). Replaces `FieldLabel`, whose all-caps micro-label belongs to
/// the older form vocabulary.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Text(
      text,
      style: tt.titleMedium!.copyWith(
        fontWeight: FontWeight.w700,
        height: 1.0,
        color: c.text1,
      ),
    );
  }
}

/// Outlined key-fact pill under the job title — rate, start date, distance
/// (Figma node 134:13361). Read-only, so it carries no button semantics.
class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      height: 32.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      // See JSelectChip — `alignment:` would stretch the pill full-width.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.btn.r),
        border: Border.all(color: c.action),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.r, color: c.actionInk),
          Gap(4.w),
          Text(
            label,
            style: tt.labelMedium!.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
              color: c.actionInk,
            ),
          ),
        ],
      ),
    );
  }
}

/// One requirement line on Job Details (Figma node 134:13388).
///
/// [met] keeps the "supplied by the builder" vs "you must bring this" split
/// the page already made — the mock draws every row identically, but flattening
/// them would drop information the tradie needs before applying.
class _ReqRow extends StatelessWidget {
  const _ReqRow({required this.icon, required this.label, required this.met});
  final IconData icon;
  final String label;
  final bool met;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 18.r, color: met ? c.text1 : c.text3),
          Gap(8.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyLarge!.copyWith(
                height: 1.0,
                color: met ? c.text1 : c.text3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Destructive confirm sheet for deleting a listing. The owning page passes the
// actual delete closure (delete + navigate + toast) as [onConfirm].
class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({required this.onConfirm});
  final Future<void> Function() onConfirm;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 20.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Delete this listing?',
            style: tt.headlineSmall!.copyWith(
              fontWeight: FontWeight.w700,
              color: c.text1,
            ),
          ),
          Gap(8.h),
          Text(
            "Applicants will no longer see it. This can't be undone "
            'from the app.',
            style: tt.bodyMedium!.copyWith(color: c.text3, height: 1.5),
          ),
          Gap(20.h),
          Row(
            children: [
              Expanded(
                child: JButton(
                  label: 'CANCEL',
                  variant: JButtonVariant.secondary,
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Gap(10.w),
              Expanded(
                child: JButton(
                  label: 'DELETE',
                  icon: AppIcons.trash,
                  variant: JButtonVariant.danger,
                  onPressed: onConfirm,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom bar shown when the tradie has already applied — a non-interactive
// "Applied" confirmation that replaces the apply button (re-applying would hit
// the UNIQUE(job_id, trade_id) constraint and surface a raw error).
class _AppliedBar extends StatelessWidget {
  const _AppliedBar();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 12.h),
      child: Container(
        width: double.infinity,
        height: 48.h,
        decoration: BoxDecoration(
          color: c.verifiedBg,
          borderRadius: BorderRadius.circular(AppRadius.btn.r),
          border: Border.all(color: c.verified),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.successCircle,
              size: AppIconSize.md.r,
              color: c.verified,
            ),
            Gap(AppSpacing.sm.w),
            Text(
              AppStrings.respondedState,
              style: tt.bodyLarge!.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: c.verifiedTx,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
