import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../domain/entities/quote_request.dart';
import '../providers/quote_requests_provider.dart';

/// Builder-side affordance on the applicant screen (#18): request a formal quote
/// from this trade for this job, then see their response inline. Distinct from
/// the trade's self-attached quote on their application.
class QuoteRequestBuilderCard extends ConsumerStatefulWidget {
  const QuoteRequestBuilderCard({
    super.key,
    required this.jobId,
    required this.tradeId,
  });

  final String jobId;
  final String tradeId;

  @override
  ConsumerState<QuoteRequestBuilderCard> createState() =>
      _QuoteRequestBuilderCardState();
}

class _QuoteRequestBuilderCardState
    extends ConsumerState<QuoteRequestBuilderCard> {
  bool _busy = false;

  Future<void> _request() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref
        .read(quoteRequestActionsProvider)
        .create(jobId: widget.jobId, tradeId: widget.tradeId);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Quote requested.' : "Couldn't send the request. Try again.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    final async = ref.watch(
      quoteRequestForProvider((jobId: widget.jobId, tradeId: widget.tradeId)),
    );

    final Widget body = async.when(
      loading: () =>
          Text('Checking…', style: tt.bodyMedium!.copyWith(color: c.text3)),
      error: (_, _) => Text(
        "Couldn't load quote status.",
        style: tt.bodyMedium!.copyWith(color: c.text2),
      ),
      data: (q) => switch (q?.status) {
        null => SizedBox(
          width: double.infinity,
          child: JButton(
            label: 'REQUEST A QUOTE',
            size: JButtonSize.compact,
            isLoading: _busy,
            onPressed: _busy ? null : _request,
          ),
        ),
        QuoteRequestStatus.requested || QuoteRequestStatus.withdrawn => Text(
          'Quote requested — awaiting their response.',
          style: tt.bodyLarge!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w600,
          ),
        ),
        QuoteRequestStatus.declined => Text(
          'This tradie declined to quote.',
          style: tt.bodyLarge!.copyWith(color: c.text2),
        ),
        QuoteRequestStatus.quoted || QuoteRequestStatus.accepted => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quoted \$${q!.quoteAmount!.toStringAsFixed(2)}',
              style: tt.titleMedium!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((q.responseNote ?? '').trim().isNotEmpty) ...[
              Gap(4.h),
              Text(
                q.responseNote!.trim(),
                style: tt.bodyMedium!.copyWith(color: c.text2),
              ),
            ],
          ],
        ),
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('FORMAL QUOTE'),
        Gap(AppSpacing.sm.h),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(AppSpacing.md.w),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(AppRadius.card.r),
            border: Border.all(color: c.border),
          ),
          child: body,
        ),
      ],
    );
  }
}
