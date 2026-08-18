import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../posts_service.dart';
import '../site_content_service.dart';
import '../widgets/post_detail_view.dart';

/// The shareable full-post page at `/post/:id` — what a shared post link
/// opens. Shows the same [PostDetailView] as the Home feed popup.
class PostDetailPage extends StatefulWidget {
  const PostDetailPage({super.key, required this.postId});

  final String postId;

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  bool _counted = false;

  @override
  void initState() {
    super.initState();
    // Opening a post through its shared link counts as a view. Failures are
    // ignored (there is no Firestore in widget tests).
    if (!_counted) {
      _counted = true;
      unawaited(
        PostsService.instance.incrementViews(widget.postId).catchError(
              (Object _) {},
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                    onPressed: () => context.go('/'),
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
            Expanded(
              child: ValueListenableBuilder<List<Post>>(
                valueListenable: PostsState.instance.posts,
                builder: (context, posts, _) {
                  if (posts.isEmpty) {
                    // Still loading the feed on a direct deep link.
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white24,
                        ),
                      ),
                    );
                  }
                  Post? post;
                  for (final p in posts) {
                    if (p.id == widget.postId) {
                      post = p;
                      break;
                    }
                  }
                  if (post == null) {
                    return const Center(
                      child: Text(
                        'Post not found',
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }
                  final content = SiteContentState.instance.content.value;
                  return PostDetailView(
                    post: post,
                    name: content?.name ?? 'N1SK',
                    avatarUrl: content?.avatarUrl ?? '',
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
