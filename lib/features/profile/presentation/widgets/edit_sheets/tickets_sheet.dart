import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fpdart/fpdart.dart' show Some;
import 'package:gap/gap.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/widgets/j_bottom_sheet.dart';
import '../../../../../core/design/widgets/j_skeleton_list.dart';
import '../../../../../core/providers/current_user_provider.dart';
import '../../../domain/entities/profile_patches.dart';
import '../../../domain/entities/site_ticket.dart';
import '../../providers/profile_provider.dart';
import '../../providers/site_tickets_provider.dart';
import 'edit_sheet_scaffold.dart';
import 'tickets_sheet_rows.dart';

/// Opens the tickets & licences picker. Returns true when a save landed.
Future<bool?> showTicketsSheet(BuildContext context) =>
    showJSheet<bool>(context: context, builder: (_) => const TicketsSheet());

/// Multi-select for the site tickets a trade holds.
///
/// Shown to EVERY trade, not just apprentices: a qualified sparky holds a
/// White Card and an EWP licence too, and scoping this to apprentices would be
/// an arbitrary limit.
///
/// Selections here are SELF-DECLARED. Verified rows come from
/// [verifiedTicketSlugsProvider] (approved, unexpired verification_documents)
/// and are locked on — the sheet never lets a user untick evidence.
class TicketsSheet extends ConsumerStatefulWidget {
  const TicketsSheet({super.key});

  @override
  ConsumerState<TicketsSheet> createState() => _TicketsSheetState();
}

class _TicketsSheetState extends ConsumerState<TicketsSheet> {
  late Set<String> _selected;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final tp = ref.read(profileControllerProvider).tradeProfile;
    _selected = {...?tp?.siteTickets};
  }

  void _toggle(String slug, bool on) {
    setState(() {
      on ? _selected.add(slug) : _selected.remove(slug);
      _dirty = true;
    });
  }

  void _explainLocked() {
    setState(() {
      _error =
          "That one's verified from a document you uploaded, so it stays on.";
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    // Sorted so the stored array is stable and a re-save of the same set is a
    // no-op diff rather than a reordered write.
    final ok = await ref
        .read(profileControllerProvider.notifier)
        .savePatches(
          trade: TradeProfilePatch(
            siteTickets: Some(_selected.toList()..sort()),
          ),
        );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _saving = false;
        _error =
            ref.read(profileControllerProvider).error ??
            "Couldn't save. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdSyncProvider);
    final ticketsAsync = ref.watch(siteTicketsProvider);
    final verified = userId == null
        ? const <String>{}
        : ref.watch(verifiedTicketSlugsProvider(userId)).asData?.value ??
              const <String>{};

    return EditSheetScaffold(
      title: 'Tickets & licences',
      isDirty: _dirty,
      isSaving: _saving,
      error: _error,
      onSave: _save,
      body: ticketsAsync.when(
        loading: () => const _TicketsSkeleton(),
        error: (_, _) => _TicketsLoadError(
          onRetry: () => ref.invalidate(siteTicketsProvider),
        ),
        data: (tickets) => _TicketsBody(
          grouped: groupTicketsByCategory(tickets),
          selected: _selected,
          verified: verified,
          onChanged: _toggle,
          onLockedTap: _explainLocked,
        ),
      ),
    );
  }
}

/// Content-shaped loading: real TicketRows fed placeholder data, masked by
/// the house shimmer. Never a spinner — MASTER reserves those for overlay and
/// inline progress, not page bodies.
class _TicketsSkeleton extends StatelessWidget {
  const _TicketsSkeleton();

  static const _placeholder = SiteTicket(
    slug: 'placeholder',
    shortName: 'White Card',
    displayName: 'White Card (Construction Induction)',
    category: SiteTicketCategory.induction,
    sortOrder: 0,
  );

  @override
  Widget build(BuildContext context) => JSkeletonList(
    enabled: true,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 6; i++)
          TicketRow(
            ticket: _placeholder,
            isSelected: false,
            isVerified: false,
            onChanged: (_) {},
          ),
      ],
    ),
  );
}

class _TicketsBody extends StatelessWidget {
  const _TicketsBody({
    required this.grouped,
    required this.selected,
    required this.verified,
    required this.onChanged,
    required this.onLockedTap,
  });

  final Map<SiteTicketCategory, List<SiteTicket>> grouped;
  final Set<String> selected;
  final Set<String> verified;
  final void Function(String slug, bool on) onChanged;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Tick what you hold. Upload to verify.',
          style: tt.bodyMedium!.copyWith(color: c.text2),
        ),
        for (final entry in grouped.entries) ...[
          TicketGroupHeader(label: entry.key.label),
          for (final ticket in entry.value)
            TicketRow(
              ticket: ticket,
              isSelected: selected.contains(ticket.slug),
              isVerified: verified.contains(ticket.slug),
              onChanged: (on) => onChanged(ticket.slug, on),
              onLockedTap: onLockedTap,
            ),
        ],
        Gap(AppSpacing.sm.h),
      ],
    );
  }
}

/// Reference-data fetch failed. Deliberately does NOT blank the sheet: the
/// user's already-selected tickets are still in the profile, and showing an
/// empty list would read as "your tickets are gone".
class _TicketsLoadError extends StatelessWidget {
  const _TicketsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Couldn't load the ticket list.",
            style: tt.bodyMedium!.copyWith(color: c.text1),
          ),
          Gap(AppSpacing.sm.h),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Tap to retry',
              style: tt.bodyMedium!.copyWith(
                color: c.actionInk,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
