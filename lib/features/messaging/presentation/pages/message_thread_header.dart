part of 'message_thread_page.dart';

/// The thread's top bar: back caret, counterparty avatar, name over a
/// subtitle, overflow glyph.
///
/// Figma `JobDun-Screens` → Messages (node 129:7406) draws it as a 16dp-margin
/// row on the base surface with no rule beneath — the avatar and the orange
/// job line are what separate it from the transcript.
class _ThreadHeader extends StatelessWidget {
  const _ThreadHeader({
    required this.name,
    required this.initials,
    required this.online,
    required this.typing,
    required this.onBack,
    this.jobTitle,
    this.avatarUrl,
  });

  final String name;
  final String initials;
  final bool online;
  final bool typing;
  final VoidCallback onBack;
  final String? jobTitle;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md.w,
        vertical: AppSpacing.sm.h,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onBack,
              // The caret is ~10dp of ink; the padding is the target.
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm.w,
                  vertical: 12.h,
                ),
                child: Icon(
                  AppIcons.back,
                  size: AppIconSize.md.r,
                  color: c.text1,
                ),
              ),
            ),
          ),
          Gap(AppSpacing.sm.w),
          _HeaderAvatar(
            initials: initials,
            online: online,
            imageUrl: avatarUrl,
          ),
          Gap(AppSpacing.md.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: tt.titleMedium!.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: c.text1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                // Subtitle priority: typing → online → job title. All
                // three share one style so the header never jumps
                // height as the state changes.
                Gap(AppSpacing.xs.h),
                if (typing)
                  Text(
                    'typing…',
                    style: tt.bodyLarge!.copyWith(
                      height: 1.4,
                      color: c.actionInk,
                    ),
                  )
                else if (online)
                  Text(
                    'Active now',
                    style: tt.bodyLarge!.copyWith(
                      height: 1.4,
                      color: c.verified,
                    ),
                  )
                else if (jobTitle != null)
                  Text(
                    jobTitle!,
                    style: tt.bodyLarge!.copyWith(
                      height: 1.4,
                      color: c.actionInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Gap(AppSpacing.sm.w),
          Icon(AppIcons.more, size: AppIconSize.md.r, color: c.text1),
        ],
      ),
    );
  }
}

// Header avatar with a green presence dot when the counterparty is online.
class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.initials,
    required this.online,
    this.imageUrl,
  });

  final String initials;
  final bool online;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        AvatarBlock(
          initials: initials,
          imageUrl: imageUrl,
          size: 40,
          circle: true,
        ),
        if (online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 11.r,
              height: 11.r,
              decoration: BoxDecoration(
                color: c.verified,
                shape: BoxShape.circle,
                border: Border.all(color: c.card, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}
