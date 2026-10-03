part of 'job_create_page.dart';

class _JobKindPicker extends StatelessWidget {
  const _JobKindPicker({required this.onChanged});
  final ValueChanged<JobKind> onChanged;

  @override
  Widget build(BuildContext context) => FormBuilderField<JobKind>(
    name: 'jobKind',
    builder: (field) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Job type',
          style: Theme.of(
            context,
          ).textTheme.titleMedium!.copyWith(color: context.c.text1),
        ),
        Gap(12.h),
        Wrap(
          spacing: 8.w,
          children: JobKind.values
              .map(
                (kind) => JSelectChip(
                  label: kind.label,
                  selected: (field.value ?? JobKind.tradeJob) == kind,
                  onTap: () {
                    field.didChange(kind);
                    onChanged(kind);
                  },
                ),
              )
              .toList(),
        ),
      ],
    ),
  );
}

/// Keeps registered form fields and typed values alive while paging back.
class _KeepCreateStep extends StatefulWidget {
  const _KeepCreateStep({required this.child});
  final Widget child;
  @override
  State<_KeepCreateStep> createState() => _KeepCreateStepState();
}

class _KeepCreateStepState extends State<_KeepCreateStep>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
