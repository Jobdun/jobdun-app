import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../providers/quote_requests_provider.dart';

/// Trade-side "respond with a price" sheet (#18). Returns nothing; on success it
/// pops itself and the inbox provider is invalidated by the action.
Future<void> showQuoteRespondSheet(
  BuildContext context, {
  required String requestId,
  String? jobTitle,
}) => showJSheet<void>(
  context: context,
  builder: (_) => _QuoteRespondSheet(requestId: requestId, jobTitle: jobTitle),
);

class _QuoteRespondSheet extends ConsumerStatefulWidget {
  const _QuoteRespondSheet({required this.requestId, this.jobTitle});

  final String requestId;
  final String? jobTitle;

  @override
  ConsumerState<_QuoteRespondSheet> createState() => _QuoteRespondSheetState();
}

class _QuoteRespondSheetState extends ConsumerState<_QuoteRespondSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final note = _note.text.trim();
    final ok = await ref
        .read(quoteRequestActionsProvider)
        .respond(
          requestId: widget.requestId,
          quoteAmount: amount,
          responseNote: note.isEmpty ? null : note,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Quote sent.')));
    } else {
      setState(() => _error = "Couldn't send your quote. Try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        AppSpacing.lg.h,
        20.w,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Respond with a quote',
            style: tt.titleLarge!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((widget.jobTitle ?? '').trim().isNotEmpty) ...[
            Gap(4.h),
            Text(
              widget.jobTitle!.trim(),
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
          ],
          Gap(AppSpacing.lg.h),
          const FieldLabel('YOUR PRICE (AUD)'),
          Gap(AppSpacing.sm.h),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            style: tt.bodyLarge!.copyWith(color: c.text1),
            decoration: const InputDecoration(
              prefixText: r'$ ',
              hintText: '0.00',
            ),
          ),
          Gap(AppSpacing.md.h),
          const FieldLabel('NOTE (OPTIONAL)'),
          Gap(AppSpacing.sm.h),
          TextField(
            controller: _note,
            maxLines: 3,
            style: tt.bodyLarge!.copyWith(color: c.text1),
            decoration: const InputDecoration(
              hintText: 'Scope, inclusions, lead time…',
            ),
          ),
          if (_error != null) ...[
            Gap(AppSpacing.sm.h),
            Text(_error!, style: tt.bodyMedium!.copyWith(color: c.urgent)),
          ],
          Gap(AppSpacing.lg.h),
          JButton(label: 'SEND QUOTE', isLoading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}
