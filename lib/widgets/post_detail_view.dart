import 'package:flutter/material.dart';

import '../format_utils.dart';
import '../posts_service.dart';
import '../share_utils.dart';
import 'linkified_text.dart';
import 'post_media.dart';

/// The full post — complete text and every attachment — plus the view count
/// and share button. Shared by the full-screen popup on the Home page and
/// the shareable `/post/:id` page, so both always show the same content.
class PostDetailView extends StatelessWidget {
  const PostDetailView({
    super.key,
    required this.post,
    required this.name,
    required this.avatarUrl,
  });

  final Post post;
  final String name;
  final String avatarUrl;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';

  bool get _wasEdited =>
      post.updatedAt != null &&
      (post.createdAt == null ||
          post.updatedAt!.difference(post.createdAt!) >=
              const Duration(minutes: 1));

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
                onBackgroundImageError: avatarUrl.isEmpty ? null : (_, _) {},
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
                    // The absolute publish date here (the feed shows a
                    // relative time); "· updated" marks an edited post.
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          post.createdAt == null
                              ? ''
                              : _formatDate(post.createdAt!),
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
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (post.coverUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  post.coverUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => Container(
                    color: Colors.white10,
                    child: const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white24,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          LinkifiedText(
            text: post.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          if (post.images.isNotEmpty ||
              post.videoUrl.isNotEmpty ||
              post.linkUrl.isNotEmpty) ...[
            const SizedBox(height: 14),
            PostAttachments(
              images: post.images,
              videoUrl: post.videoUrl,
              linkUrl: post.linkUrl,
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.visibility_outlined,
                size: 18,
                color: Colors.white54,
              ),
              const SizedBox(width: 5),
              Text(
                '${formatCount(post.views)} views',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: Colors.white54,
                          ),
                          SizedBox(width: 6),
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
            ],
          ),
        ],
      ),
    );
  }
}

/// The full-screen post popup opened from the Home feed. Renders the post
/// live from [PostsState], so the view count ticks up while it's open.
class PostDetailDialog extends StatelessWidget {
  const PostDetailDialog({
    super.key,
    required this.postId,
    required this.post,
    required this.name,
    required this.avatarUrl,
  });

  final String postId;
  final Post post;
  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF000000),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text(
                    'Post',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _LivePostBody(
              postId: postId,
              fallback: post,
              name: name,
              avatarUrl: avatarUrl,
            )),
          ],
        ),
      ),
    );
  }
}

/// Finds the post in the live list by id (falling back to the snapshot it
/// was opened with) so the dialog and the share page both update in place.
class _LivePostBody extends StatelessWidget {
  const _LivePostBody({
    required this.postId,
    required this.fallback,
    required this.name,
    required this.avatarUrl,
  });

  final String postId;
  final Post fallback;
  final String name;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Post>>(
      valueListenable: PostsState.instance.posts,
      builder: (context, posts, _) {
        Post? current;
        for (final post in posts) {
          if (post.id == postId) {
            current = post;
            break;
          }
        }
        return PostDetailView(
          post: current ?? fallback,
          name: name,
          avatarUrl: avatarUrl,
        );
      },
    );
  }
}
