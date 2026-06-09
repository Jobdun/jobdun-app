import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:jobdun/core/theme/app_icons.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/j_button.dart';
import '../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../core/design/widgets/j_staggered_list.dart';
import '../../../../core/design/widgets/page_header.dart';
import '../../domain/entities/quote_request.dart';
import '../providers/quote_requests_provider.dart';
import '../widgets/quote_respond_sheet.dart';

/// Trade inbox for builder-initiated quote requests (#18). Reached from
/// Settings → Quote requests (trade accounts). Each pending request can be
/// answered with a price or declined.
class QuoteRequestsInboxPage extends ConsumerWidget {
  const QuoteRequestsInboxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(receivedQuoteRequestsProvider);

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: c.card,
              padding: EdgeInsets.fromLTRB(4.w, AppSpacing.sm.h, 20.w, 12.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(
                      AppIcons.back,
                      size: AppIconSize.md.r,
                      color: c.text1,
                    ),
                  ),
                  const Expanded(
                    child: PageHeader(
                      title: 'Quote requests',
                      size: PageHeaderSize.sub,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Expanded(
              child: async.when(
                loading: () => JSkeletonList(
                  enabled: true,
                  child: ListView(
                    padding: EdgeInsets.all(20.w),
                    children: List.generate(
                      3,
                      (_) => Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Container(
                          height: 120.h,
                          decoration: BoxDecoration(
                            color: c.surface,
                            borderRadius: BorderRadius.circular(
                              AppRadius.card.r,
                            ),
                            border: Border.all(color: c.border),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                error: (_, _) => _Centered(
                  icon: AppIcons.warning,
                  title: "Couldn't load your quote requests.",
                  subtitle: 'Pull down to retry.',
                ),
                data: (list) => list.isEmpty
                    ? _Centered(
                        icon: AppIcons.document,
                        title: 'No quote requests yet',
                        subtitle:
                            'When a builder asks you to quote a job, it shows up here.',
                      )
                    : RefreshIndicator(
                        color: c.action,
                        backgroundColor: c.card,
                        onRefresh: () async =>
                            ref.invalidate(receivedQuoteRequestsProvider),
                        child: JStaggeredList(
                          padding: EdgeInsets.all(20.w),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => Gap(12.h),
                          itemBuilder: (_, i) =>
                              _QuoteRequestCard(req: list[i]),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return ListView(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      children: [
        Gap(80.h),
        Icon(icon, size: 48.r, color: c.text3),
        Gap(AppSpacing.md.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: tt.titleMedium!.copyWith(
            color: c.text1,
            fontWeight: FontWeight.w700,
          ),
        ),
        Gap(AppSpacing.sm.h),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
      ],
    );
  }
}

class _QuoteRequestCard extends ConsumerWidget {
  const _QuoteRequestCard({required this.req});

  final QuoteRequest req;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md.w),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.card.r),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            req.jobTitle ?? 'A job',
            style: tt.titleMedium!.copyWith(
              color: c.text1,
              fontWeight: FontWeight.w700,
            ),
          ),
          if ((req.builderCompanyName ?? '').trim().isNotEmpty) ...[
            Gap(2.h),
            Text(
              req.builderCompanyName!.trim(),
              style: tt.bodyMedium!.copyWith(color: c.text2),
            ),
          ],
          if ((req.requestNote ?? '').trim().isNotEmpty) ...[
            Gap(AppSpacing.sm.h),
            Text(
              req.requestNote!.trim(),
              style: tt.bodyMedium!.copyWith(color: c.text2, height: 1.4),
            ),
          ],
          Gap(AppSpacing.md.h),
          if (req.isAwaitingResponse)
            Row(
              children: [
                Expanded(
                  child: JButton(
                    label: 'QUOTE',
                    size: JButtonSize.compact,
                    onPressed: () => showQuoteRespondSheet(
                      context,
                      requestId: req.id,
                      jobTitle: req.jobTitle,
                    ),
                  ),
                ),
                Gap(12.w),
                Expanded(
                  child: JButton(
                    label: 'DECLINE',
                    size: JButtonSize.compact,
                    variant: JButtonVariant.secondary,
                    onPressed: () => _decline(context, ref),
                  ),
                ),
              ],
            )
          else
            Text(
              switch (req.status) {
                QuoteRequestStatus.quoted =>
                  'You quoted \$${(req.quoteAmount ?? 0).toStringAsFixed(2)}',
                QuoteRequestStatus.accepted => 'Accepted by the builder',
                QuoteRequestStatus.declined => 'You declined',
                _ => req.status.label,
              },
              style: tt.bodyLarge!.copyWith(
                color: c.text1,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _decline(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(quoteRequestActionsProvider).decline(req.id);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Request declined.' : "Couldn't decline.")),
    );
  }
}
