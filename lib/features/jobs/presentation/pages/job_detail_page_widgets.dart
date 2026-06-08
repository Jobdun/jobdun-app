part of 'job_detail_page.dart';

// Presentational leaves for the job detail page — split into a `part` so the
// page stays under the file-size budget. Single-use, co-located with the page.

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip.r),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppIconSize.micro.r, color: c.text3),
          Gap(6.w),
          Text(label, style: tt.labelMedium!.copyWith(color: c.text2)),
        ],
      ),
    );
  }
}

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
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Icon(
            icon,
            size: AppIconSize.inline.r,
            color: met ? c.text2 : c.text3,
          ),
          Gap(10.w),
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium!.copyWith(color: met ? c.text2 : c.text3),
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
