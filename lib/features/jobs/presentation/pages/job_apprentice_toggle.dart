part of 'job_create_page.dart';

// ── Open-to-apprentices toggle ─────────────────────────────────────────────────
//
// An INVITATION, not a gate. requires_verified / requires_public_liability are
// rendered on the job card but never enforced at apply time (verified
// 2026-08-30: no apply-path check exists), so there is nothing here to waive.
// Turning this on adds an OPEN TO APPRENTICES chip to the listing and puts the
// job in the apprentice-side filter.
//
// Its own part file rather than an addition to job_create_page_widgets.dart,
// which was already at 391 lines against the 400-line target.

class _OpenToApprenticesToggle extends StatelessWidget {
  const _OpenToApprenticesToggle();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return FormBuilderField<bool>(
      name: 'open_to_apprentices',
      builder: (field) {
        final isOn = field.value ?? false;
        return Container(
          padding: EdgeInsets.all(16.r),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(AppRadius.cardLg.r),
            border: Border.all(color: isOn ? c.action : c.border),
          ),
          child: Row(
            children: [
              Icon(
                AppIcons.trade,
                size: 24.r,
                color: isOn ? c.actionInk : c.text2,
              ),
              Gap(8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Open to apprentices',
                      style: tt.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.0,
                        color: c.text1,
                      ),
                    ),
                    Gap(4.h),
                    Text(
                      "Invites apprentices to apply. Doesn't change your other "
                      'requirements.',
                      style: tt.bodyMedium!.copyWith(
                        height: 1.4,
                        color: c.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Gap(8.w),
              JSwitch(
                value: isOn,
                onChanged: (v) {
                  HapticFeedback.lightImpact();
                  field.didChange(v);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
