import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

/// The attachment block of a post — an inline video, the images (one large
/// or a two-column grid) and a link card. Shared by the feed card and the
/// full-post view so a post's attachments always render identically.
class PostAttachments extends StatelessWidget {
  const PostAttachments({
    super.key,
    required this.images,
    this.videoUrl = '',
    this.linkUrl = '',
  });

  final List<String> images;
  final String videoUrl;
  final String linkUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (videoUrl.isNotEmpty) ...[
          PostVideoPlayer(url: videoUrl),
          const SizedBox(height: 10),
        ],
        ..._imageWidgets(),
        if (linkUrl.isNotEmpty) ...[
          if (videoUrl.isNotEmpty || images.isNotEmpty)
            const SizedBox(height: 10),
          LinkCard(url: linkUrl),
        ],
      ],
    );
  }

  List<Widget> _imageWidgets() {
    if (images.isEmpty) return const [];
    if (images.length == 1) {
      return [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: Image.network(
              images.first,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (_, _, _) => const _BrokenImage(),
            ),
          ),
        ),
      ];
    }
    final widgets = <Widget>[];
    for (var i = 0; i < images.length; i += 2) {
      final hasSecond = i + 1 < images.length;
      widgets.add(
        Row(
          children: [
            Expanded(child: _SquareImage(url: images[i])),
            if (hasSecond) ...[
              const SizedBox(width: 8),
              Expanded(child: _SquareImage(url: images[i + 1])),
            ],
          ],
        ),
      );
      if (i + 2 < images.length) widgets.add(const SizedBox(height: 8));
    }
    return widgets;
  }
}

class _SquareImage extends StatelessWidget {
  const _SquareImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const _BrokenImage(),
        ),
      ),
    );
  }
}

class _BrokenImage extends StatelessWidget {
  const _BrokenImage();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white10,
      child: const Center(
        child: Icon(Icons.broken_image_outlined, color: Colors.white24),
      ),
    );
  }
}

/// An inline video player. Loads the first frame without autoplaying; a tap
/// toggles play/pause and a thin progress bar sits at the bottom. Videos
/// that fail to load show a quiet placeholder rather than an error.
class PostVideoPlayer extends StatefulWidget {
  const PostVideoPlayer({super.key, required this.url});

  final String url;

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  late final VideoPlayerController _controller =
      VideoPlayerController.networkUrl(Uri.parse(widget.url));
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller.initialize().then((_) {
      if (mounted) setState(() => _ready = true);
    }).catchError((Object _) {
      // A video that can't load just shows the placeholder.
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: _ready
            ? Stack(
                children: [
                  VideoPlayer(_controller),
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          _controller.value.isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 6,
                    child: VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                    ),
                  ),
                ],
              )
            : Container(
                color: Colors.white10,
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white24,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// A tappable card showing a link attachment — the domain on top, the full
/// URL below; tapping opens it in a new tab.
class LinkCard extends StatelessWidget {
  const LinkCard({super.key, required this.url});

  final String url;

  Future<void> _open() async {
    try {
      var target = url.trim();
      if (!target.startsWith('http://') && !target.startsWith('https://')) {
        target = 'https://$target';
      }
      await launchUrl(Uri.parse(target), webOnlyWindowName: '_blank');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? url;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.link, size: 18, color: Colors.white54),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host.isEmpty ? url : host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
