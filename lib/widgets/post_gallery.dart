import 'package:flutter/material.dart';

/// Opens the fullscreen swipe gallery for a post's images, starting at
/// [initialIndex]. Pushed as its own opaque route on top of whatever screen
/// (feed, detail popup, share page) the image was tapped from.
Future<void> showPostGallery(
  BuildContext context, {
  required List<String> images,
  int initialIndex = 0,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: true,
      barrierColor: const Color(0xFF000000),
      pageBuilder: (_, _, _) => PostGallery(
        images: images,
        initialIndex: initialIndex,
      ),
    ),
  );
}

/// Fullscreen dark viewer: swipe horizontally between a post's images, a
/// "1/4" counter at the bottom and a close button at the top. Images that
/// fail to load show a quiet placeholder instead of an error.
class PostGallery extends StatefulWidget {
  const PostGallery({super.key, required this.images, this.initialIndex = 0});

  final List<String> images;
  final int initialIndex;

  @override
  State<PostGallery> createState() => _PostGalleryState();
}

class _PostGalleryState extends State<PostGallery> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.images.length,
                onPageChanged: (page) => setState(() => _index = page),
                itemBuilder: (context, index) {
                  return InteractiveViewer(
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => Container(
                          color: Colors.white10,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white24,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            // Close button, top-left like the post popup.
            Positioned(
              top: 0,
              left: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            // "1/4" style position indicator, bottom center.
            if (widget.images.length > 1)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${_index + 1}/${widget.images.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
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
