part of 'message_thread_page.dart';

// An image attachment bubble. Resolves a signed URL for the private object,
// renders it with a cached network image, and opens a zoomable full-screen
// viewer on tap. Part of the page library so it shares its imports.
class _ChatImage extends ConsumerWidget {
  const _ChatImage({required this.path, this.width, this.height});

  final String path;
  final int? width;
  final int? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final async = ref.watch(signedChatUrlProvider(path));
    final ratio =
        ((width != null && height != null && height! > 0)
                ? (width! / height!).clamp(0.6, 1.7)
                : 1.3)
            .toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(14.r),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 240.w),
        child: AspectRatio(
          aspectRatio: ratio,
          child: async.when(
            data: (url) => GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => _ImageViewer(url: url, tag: path),
                ),
              ),
              child: Hero(
                tag: path,
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.surface),
                  errorWidget: (_, _, _) => const _ImageError(),
                ),
              ),
            ),
            loading: () => ColoredBox(color: c.surface),
            error: (_, _) => const _ImageError(),
          ),
        ),
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      color: c.surface,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: c.text3),
    );
  }
}

// Full-screen zoomable image viewer.
class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.url, required this.tag});

  final String url;
  final String tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // intentional
      appBar: AppBar(
        backgroundColor: Colors.black, // intentional
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), // intentional
      ),
      body: Hero(
        tag: tag,
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(url),
          backgroundDecoration: const BoxDecoration(
            color: Colors.black, // intentional
          ),
        ),
      ),
    );
  }
}
