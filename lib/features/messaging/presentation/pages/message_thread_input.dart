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
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        10.h,
        AppSpacing.md.w,
        10.h,
      ),
      child: Row(
        children: [
          // Attach a photo.
          GestureDetector(
            key: const Key('thread-attach'),
            onTap: () {
              HapticFeedback.lightImpact();
              onAttach();
            },
            child: Padding(
              padding: EdgeInsets.only(right: AppSpacing.sm.w),
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 28.r,
                color: c.text2,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(24.r),
                border: Border.all(color: c.border),
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
                  hintText: 'Message…',
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
          Gap(10.w),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = value.text.trim().isNotEmpty;
              return GestureDetector(
                key: const Key('thread-send'),
                onTap: canSend ? onSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 42.r,
                  height: 42.r,
                  decoration: BoxDecoration(
                    color: canSend ? c.action : c.surfaceRaised,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    AppIcons.send,
                    size: AppIconSize.md.r,
                    color: canSend ? c.onAction : c.text3,
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
