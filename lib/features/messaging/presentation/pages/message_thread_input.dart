part of 'message_thread_page.dart';

// The bottom composer: attach button + text field + send button. Extracted into
// a `part` so the page stays under the file-size budget. Uses the page's text
// controller; typing-broadcast stays wired via the controller's listener.
class _ThreadComposer extends StatelessWidget {
  const _ThreadComposer({
    required this.controller,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    // Figma `JobDun-Screens` → Messages (node 129:7331): a 16dp bar on the
    // base surface — a bare 32dp attach glyph, the pill field, a bare 32dp
    // send glyph. No rule above it; the field's own edge does the separating.
    return Container(
      color: c.card,
      padding: EdgeInsets.all(AppSpacing.md.r),
      child: Row(
        children: [
          // Attach a photo.
          Semantics(
            button: true,
            label: 'Attach a photo',
            child: GestureDetector(
              key: const Key('thread-attach'),
              behavior: HitTestBehavior.opaque,
              onTap: () {
                HapticFeedback.lightImpact();
                onAttach();
              },
              child: Icon(
                AppIcons.image,
                size: AppIconSize.feature.r,
                color: c.text2,
              ),
            ),
          ),
          Gap(AppSpacing.sm.w),
          Expanded(
            child: Container(
              constraints: BoxConstraints(minHeight: 48.h),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(AppRadius.btn.r),
                // borderStrong, not border: this is an interactive control
                // edge and owes the 3:1 floor (MASTER → Accessibility).
                border: Border.all(color: c.borderStrong),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md.w,
                vertical: 4.h,
              ),
              child: TextField(
                controller: controller,
                style: tt.bodyLarge!.copyWith(color: c.text1),
                maxLines: null,
                // Text guardrail: hard cap input length; counter hidden.
                maxLength: kMaxMessageLength,
                buildCounter:
                    (
                      _, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) => null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  // Figma tints the placeholder at `text/subtle`; that lands
                  // at 2.85:1, and a placeholder is content — so it reads at
                  // `text3` instead.
                  hintText: 'Message',
                  hintStyle: tt.bodyLarge!.copyWith(color: c.text3),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(vertical: 8.h),
                  isDense: true,
                ),
              ),
            ),
          ),
          Gap(AppSpacing.sm.w),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty;
              return Semantics(
                button: true,
                enabled: canSend,
                label: 'Send message',
                child: GestureDetector(
                  key: const Key('thread-send'),
                  behavior: HitTestBehavior.opaque,
                  onTap: canSend ? onSend : null,
                  // A bare plane, per Figma — the orange is the ink here, so
                  // it reads through `actionInk`, not the fill token.
                  child: Icon(
                    AppIcons.send,
                    size: AppIconSize.feature.r,
                    color: canSend ? c.actionInk : c.text3,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Camera vs gallery chooser for attaching a photo.
class _ImageSourceSheet extends StatelessWidget {
  const _ImageSourceSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Gap(AppSpacing.sm.h),
          _SourceRow(
            icon: Icons.photo_camera_outlined,
            label: 'Take photo',
            source: ImageSource.camera,
          ),
          _SourceRow(
            icon: Icons.photo_library_outlined,
            label: 'Choose from gallery',
            source: ImageSource.gallery,
          ),
          Gap(AppSpacing.sm.h),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({
    required this.icon,
    required this.label,
    required this.source,
  });

  final IconData icon;
  final String label;
  final ImageSource source;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.pop(context, source);
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        child: Row(
          children: [
            Icon(icon, size: AppIconSize.md.r, color: c.text1),
            Gap(16.w),
            Text(
              label,
              style: tt.titleMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: c.text1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown in place of the composer when the conversation is frozen by a block
/// (either side). Honest lockout: no input, no failing retry bubbles.
class _BlockedBanner extends StatelessWidget {
  const _BlockedBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      color: c.surface,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(AppIcons.block, size: AppIconSize.inline.r, color: c.text3),
            Gap(8.w),
            Text(
              'THIS CONVERSATION IS BLOCKED.',
              style: tt.labelLarge!.copyWith(
                color: c.text3,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
