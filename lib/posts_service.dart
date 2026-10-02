import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The label of the catch-all tab — every post, whatever its folder.
const String updatesTabLabel = 'Updates';

/// A published post — one item in the Home feed, filed under a folder (the
/// tabs on the Home page).
class Post {
  const Post({
    required this.id,
    required this.folder,
    required this.text,
    this.images = const [],
    this.videoUrl = '',
    this.linkUrl = '',
    this.coverUrl = '',
    this.views = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String folder;
  final String text;

  /// Uploaded attachment URLs (up to 4 images).
  final List<String> images;
  final String videoUrl;
  final String linkUrl;

  /// Optional banner image for article-length posts (separate from [images]).
  final String coverUrl;

  /// How many times the post has been opened (tapped).
  final int views;

  /// When the post was published.
  final DateTime? createdAt;

  /// When the post was last edited; null = never edited.
  final DateTime? updatedAt;

  factory Post.fromData(String id, Map<String, dynamic> data) {
    DateTime? parseDate(Object? value) =>
        value is String ? DateTime.tryParse(value) : null;
    return Post(
      id: id,
      folder: (data['folder'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      images: ((data['images'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      videoUrl: (data['video_url'] as String?) ?? '',
      linkUrl: (data['link_url'] as String?) ?? '',
      coverUrl: (data['cover_url'] as String?) ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  Map<String, dynamic> toData() => {
        'folder': folder,
        'text': text,
        'images': images,
        'video_url': videoUrl,
        'link_url': linkUrl,
        'cover_url': coverUrl,
        'views': views,
      };
}

/// In-memory posts for the widget tree, fed by the Supabase realtime stream
/// subscribed in `main()` — the same backend-free pattern as
/// [SiteContentState], so the widget tests run without a database.
class PostsState {
  PostsState._();

  static final PostsState instance = PostsState._();

  final ValueNotifier<List<Post>> posts = ValueNotifier<List<Post>>([]);

  /// Distinct folder names in first-appearance order — the Home tabs.
  List<String> get folders {
    final seen = <String>{};
    return [
      for (final post in posts.value)
        if (seen.add(post.folder)) post.folder,
    ];
  }
}

/// Reads and writes posts (the `posts` table in Postgres, attachments in
/// the `posts` storage bucket).
class PostsService {
  PostsService._();

  static final PostsService instance = PostsService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Live stream of all posts, newest first.
  Stream<List<Post>> watchPosts() {
    return _client.from('posts').stream(primaryKey: ['id']).map((rows) {
      final posts = [
        for (final row in rows) Post.fromData(row['id'] as String, row),
      ];
      posts.sort(
        (a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000)),
      );
      return posts;
    });
  }

  /// Publishes a new post and returns its id. The server stamps the
  /// publish time itself (`created_at` defaults to now() in the database —
  /// the Postgres version of a server timestamp).
  Future<String> createPost({
    required String folder,
    required String text,
    List<String> images = const [],
    String videoUrl = '',
    String linkUrl = '',
    String coverUrl = '',
  }) async {
    final row = await _client.from('posts').insert({
      'folder': folder,
      'text': text,
      'images': images,
      'video_url': videoUrl,
      'link_url': linkUrl,
      'cover_url': coverUrl,
      'views': 0,
    }).select('id').single();
    return row['id'] as String;
  }

  /// Overwrites a post in place, keeping its original publish time and
  /// view count (the update never touches `created_at`), so an edit doesn't
  /// reorder the feed or reset the stats. Marks the post as edited with a
  /// fresh `updated_at`.
  Future<void> updatePost(Post post) async {
    await _client.from('posts').update({
      ...post.toData(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', post.id);
  }

  Future<void> deletePost(String id) async {
    await _client.from('posts').delete().eq('id', id);
  }

  /// Counts one more view on the post — the server-side "+1 only"
  /// vending machine; works without signing in.
  Future<void> incrementViews(String id) async {
    await _client.rpc('increment_post_views', params: {'p_post_id': id});
  }

  /// Uploads an attachment (image or video) to the `posts` bucket and
  /// returns its public URL.
  Future<String> uploadFile({
    required Uint8List bytes,
    required String name,
    required String contentType,
  }) async {
    await _client.storage.from('posts').uploadBinary(
          name,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('posts').getPublicUrl(name);
  }
}
