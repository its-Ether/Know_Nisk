import 'package:flutter/material.dart';

import '../posts_service.dart';
import '../share_utils.dart';
import 'post_media.dart';

/// One post in the Home feed, styled like an X post: admin avatar + name +
/// date, the text clamped to a few lines ending with an ellipsis (the full
/// text lives in the post popup), the attachments, and a footer with the
/// view count and a share button. No likes.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.name,
    required this.avatarUrl,
    this.onTap,
  });

  final Post post;
  final String name;
  final String avatarUrl;

  /// What a tap on the post does — Home opens the full-post popup, the
  /// admin editor opens its manage dialog. Null keeps the card inert.
  final VoidCallback? onTap;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  String _viewsLabel(int views) => views == 1 ? '1 view' : '$views views';

  @override
  Widget build(BuildContext context) {
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white10,
                    backgroundImage: avatarUrl.isEmpty
                        ? const AssetImage('assets/avatar_placeholder.png')
                        : NetworkImage(avatarUrl),
                    onBackgroundImageError: avatarUrl.isEmpty
                        ? null
                        : (_, _) {},
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          post.createdAt == null
                              ? ''
                              : _formatDate(post.createdAt!),
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
              const SizedBox(height: 10),
              // The feed shows a few lines ending with "…"; the full text
              // only appears in the post popup, just like X.
              Text(
                post.text,
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
              Row(
                children: [
                  const Icon(
                    Icons.visibility_outlined,
                    size: 16,
                    color: Colors.white54,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _viewsLabel(post.views),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Share',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => sharePost(context, post),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
