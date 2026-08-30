import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:gap/gap.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/widgets/field_label.dart';
import '../providers/site_tickets_provider.dart';
import 'ticket_chip_wall.dart';

/// The "Tickets & licences" block on a trade profile.
///
/// Reads the self-declared slugs off the profile and the verified set off
/// [verifiedTicketSlugsProvider], then renders them as two visually distinct
/// tiers. The two lists are never merged: a tick is a claim, a green chip is a
/// document a human approved.
///
/// Renders nothing when the trade has declared no tickets AND is not the
/// owner — an empty section on someone else's profile is noise. The owner sees
/// a prompt instead, because for an apprentice this block is most of the pitch.
class ProfileTicketsSection extends ConsumerWidget {
  const ProfileTicketsSection({
    super.key,
    required this.userId,
    required this.selectedSlugs,
    this.isOwner = false,
    this.onAdd,
  });

  final String userId;
  final List<String> selectedSlugs;
  final bool isOwner;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    if (selectedSlugs.isEmpty && !isOwner) return const SizedBox.shrink();

    final labels = ref.watch(siteTicketsProvider).asData?.value ?? const [];
    final labelsBySlug = {for (final t in labels) t.slug: t.shortName};
    final verified =
        ref.watch(verifiedTicketSlugsProvider(userId)).asData?.value ??
        const <String>{};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const FieldLabel.section('Tickets & licences'),
        Gap(AppSpacing.sm.h),
        if (selectedSlugs.isEmpty)
          GestureDetector(
            onTap: onAdd,
            child: Text(
              'Add the tickets you hold so builders can filter for you',
              style: tt.bodyMedium!.copyWith(color: c.text3),
            ),
          )
        else
          TicketChipWall(
            labelsBySlug: labelsBySlug,
            selectedSlugs: selectedSlugs,
            verifiedSlugs: verified,
            // The disclaimer is for whoever is deciding whether to put this
            // person on site, which is never the profile's owner.
            showDisclaimer: !isOwner,
          ),
      ],
    );
  }
}
