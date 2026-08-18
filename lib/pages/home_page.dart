import 'dart:async';

import 'package:flutter/material.dart';

import '../browser_storage.dart';
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
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    _maybeCountSiteView();
  }

  /// Counts one site view, but at most once per browser per 24 hours — the
  /// header counter would otherwise inflate on every refresh. All failures
  /// are swallowed: no Firestore in widget tests, and an offline viewer
  /// should still see the page.
  void _maybeCountSiteView() {
    try {
      const key = 'know_site_viewed_at';
      final last = localStorageGet(key);
      if (last != null) {
        final seen = DateTime.tryParse(last);
        if (seen != null &&
            DateTime.now().difference(seen).inHours < 24) {
          return;
        }
      }
      localStorageSet(key, DateTime.now().toIso8601String());
      unawaited(
        SiteContentService.instance.incrementSiteView().catchError(
              (Object _) {},
            ),
      );
    } catch (_) {}
  }

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
