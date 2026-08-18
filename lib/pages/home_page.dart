import 'dart:async';

import 'package:flutter/material.dart';

import '../posts_service.dart';
import '../site_content_service.dart';
import '../widgets/post_detail_view.dart';
import '../widgets/profile_view.dart';

/// Home — the first page of Know N1SK, styled like an X profile screen.
///
/// The whole screen is the shared [ProfileView] (cover, avatar, name,
/// username, bio, updated-on, views, folder tabs + post feed) fed by the
/// site content and posts from Firestore. Until content exists, the
/// approved placeholder art + text are shown. Content is edited on
/// `/admin-editor` and published live.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// Opens the full post popup. Each open counts as a view on the post;
  /// failures are ignored so a broken counter never breaks the page (there
  /// is no Firestore in widget tests).
  void _openPost(
    BuildContext context,
    Post post,
    String name,
    String avatarUrl,
  ) {
    unawaited(
      PostsService.instance.incrementViews(post.id).catchError((Object _) {}),
    );
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => PostDetailDialog(
        postId: post.id,
        post: post,
        name: name,
        avatarUrl: avatarUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ValueListenableBuilder<SiteContent?>(
        valueListenable: SiteContentState.instance.content,
        builder: (context, content, _) => ProfileView(
          content: content,
          onPostTap: (post) => _openPost(
            context,
            post,
            content?.name ?? 'N1SK',
            content?.avatarUrl ?? '',
          ),
        ),
      ),
    );
  }
}
