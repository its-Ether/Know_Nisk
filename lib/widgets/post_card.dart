import 'package:flutter/material.dart';

import '../format_utils.dart';
import '../posts_service.dart';
import '../share_utils.dart';
import 'linkified_text.dart';
import 'post_media.dart';

/// One post in the Home feed, styled like an X post: admin avatar + name +
/// the meta row (relative date, "· updated" when edited, a "New" chip for
/// fresh posts and — on the Updates feed only — a chip with the post's
/// folder), the text clamped to a few lines ending with an ellipsis (the
/// full text — and the article cover banner, if any — live in the post
/// popup), the attachments, and a left-aligned footer with views, share and
/// read time that scrolls horizontally instead of overflowing. No likes.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.name,
    required this.avatarUrl,
    this.onTap,
    this.showFolderChip = false,
  });

  final Post post;
  final String name;
  final String avatarUrl;

  /// What a tap on the post does — Home opens the full-post popup, the
  /// admin editor opens its manage dialog. Null keeps the card inert.
  final VoidCallback? onTap;

  /// True on the catch-all "Updates" feed, where posts from every folder mix
  /// and the folder chip is the only way to tell them apart. Folder tabs
  /// leave it off — the viewer already knows the folder there.
  final bool showFolderChip;

  bool get _isNew =>
      post.createdAt != null &&
      DateTime.now().difference(post.createdAt!) < const Duration(hours: 24);

  bool get _wasEdited =>
      post.updatedAt != null &&
      (post.createdAt == null ||
          post.updatedAt!.difference(post.createdAt!) >=
              const Duration(minutes: 1));

  String _viewsLabel(int views) {
    final formatted = formatCount(views);
    return views == 1 ? '1 view' : '$formatted views';
  }

  @override
  Widget build(BuildContext context) {
    final readTime = readTimeMinutes(post.text);
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Same ring + faint halo as the profile avatar (N1SK).
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0xFF262626), width: 0.6),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x2EFFFFFF), // white @ 18% — faint halo
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white10,
                      backgroundImage: avatarUrl.isEmpty
                          ? const AssetImage('assets/avatar_placeholder.png')
                          : NetworkImage(avatarUrl),
                      onBackgroundImageError: avatarUrl.isEmpty
                          ? null
                          : (_, _) {},
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          // Same face as the profile name (N1SK).
                          style: const TextStyle(
                            fontFamily: 'Sekuya',
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Relative time + "· updated" + the New / folder
                        // chips. A Wrap so a crowded header folds onto a
                        // second line instead of overflowing on narrow cards.
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              post.createdAt == null
                                  ? ''
                                  : formatRelativeTime(post.createdAt!),
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            if (_wasEdited)
                              const Text(
                                '· updated',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            if (_isNew) const _Chip(label: 'New', accent: true),
                            if (showFolderChip && post.folder.isNotEmpty)
                              _Chip(label: post.folder),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // The feed shows a few lines ending with "…"; the full text
              // (and the article cover banner, if the post has one) only
              // appears in the post popup, just like X. Bare URLs in the
              // text render as tappable blue links.
              LinkifiedText(
                text: post.text,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              if (post.images.isNotEmpty ||
                  post.videoUrl.isNotEmpty ||
                  post.linkUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                PostAttachments(
                  images: post.images,
                  videoUrl: post.videoUrl,
                  linkUrl: post.linkUrl,
                ),
              ],
              const SizedBox(height: 12),
              // Left-aligned action row: views, share, read time — nothing on
              // the right. It scrolls horizontally once it outgrows the card,
              // so future actions never overflow the layout.
              _PostFooter(
                viewsLabel: _viewsLabel(post.views),
                readTime: readTime,
                onShare: () => sharePost(context, post),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The small outlined pill used for the "New" and folder chips. "New" is
/// tinted with the site's blue accent so fresh posts stand out quietly.
class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.accent = false});

  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? Colors.blue : Colors.white54;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: accent ? Colors.blue : Colors.white24),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: accent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// The post footer: views · share · read time, left-aligned in a horizontal
/// scroll view. When the row outgrows the card a soft gradient fades the
/// right edge so it reads as scrollable rather than clipped.
class _PostFooter extends StatefulWidget {
  const _PostFooter({
    required this.viewsLabel,
    required this.onShare,
    this.readTime,
  });

  final String viewsLabel;
  final VoidCallback onShare;
  final int? readTime;

  @override
  State<_PostFooter> createState() => _PostFooterState();
}

class _PostFooterState extends State<_PostFooter> {
  final ScrollController _controller = ScrollController();
  bool _overflowing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateOverflow);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateOverflow());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateOverflow() {
    if (!mounted || !_controller.hasClients) return;
    final overflowing = _controller.position.maxScrollExtent > 0;
    if (overflowing != _overflowing) setState(() => _overflowing = overflowing);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              Tooltip(
                message: 'Views',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.visibility_outlined,
                      size: 16,
                      color: Colors.white54,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.viewsLabel,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Tooltip(
                message: 'Share',
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onShare,
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 16,
                            color: Colors.white54,
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (widget.readTime != null) ...[
                const SizedBox(width: 18),
                Tooltip(
                  message: 'Read time',
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        size: 16,
                        color: Colors.white54,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '~${widget.readTime} min read',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_overflowing)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: 28,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Color(0xFF000000)],
                    stops: [0, 1],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
