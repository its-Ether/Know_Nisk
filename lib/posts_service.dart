import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

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

  /// When the post was published (server timestamp).
  final DateTime? createdAt;

  /// When the post was last edited (server timestamp); null = never edited.
  final DateTime? updatedAt;

  factory Post.fromData(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final updated = data['updatedAt'];
    return Post(
      id: id,
      folder: (data['folder'] as String?) ?? '',
      text: (data['text'] as String?) ?? '',
      images: ((data['images'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      videoUrl: (data['videoUrl'] as String?) ?? '',
      linkUrl: (data['linkUrl'] as String?) ?? '',
      coverUrl: (data['coverUrl'] as String?) ?? '',
      views: (data['views'] as num?)?.toInt() ?? 0,
      createdAt: created is Timestamp ? created.toDate() : null,
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toData() => {
        'folder': folder,
        'text': text,
        'images': images,
        'videoUrl': videoUrl,
        'linkUrl': linkUrl,
        'coverUrl': coverUrl,
        'views': views,
      };
}

/// In-memory posts for the widget tree, fed by the Firestore stream
/// subscribed in `main()` — the same Firebase-free pattern as
/// [SiteContentState], so the widget tests run without a Firebase app.
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

/// Reads and writes posts (`posts` in Firestore, attachments in Storage
/// under `posts/`).
class PostsService {
  PostsService._();

  static final PostsService instance = PostsService._();

  CollectionReference<Map<String, dynamic>> get _posts =>
      FirebaseFirestore.instance.collection('posts');

  /// Live stream of all posts, newest first.
  Stream<List<Post>> watchPosts() {
    return _posts.orderBy('createdAt', descending: true).snapshots().map(
          (snapshot) => [
            for (final doc in snapshot.docs) Post.fromData(doc.id, doc.data()),
          ],
        );
  }

  /// Publishes a new post and returns its id.
  Future<String> createPost({
    required String folder,
    required String text,
    List<String> images = const [],
    String videoUrl = '',
    String linkUrl = '',
    String coverUrl = '',
  }) async {
    final ref = await _posts.add({
      'folder': folder,
      'text': text,
      'images': images,
      'videoUrl': videoUrl,
      'linkUrl': linkUrl,
      'coverUrl': coverUrl,
      'views': 0,
      'createdAt': FieldValue.serverTimestamp(),
      // No updatedAt on creation — a brand-new post was never edited.
    });
    return ref.id;
  }

  /// Overwrites a post in place, keeping its original publish time and view
  /// count, so an edit doesn't reorder the feed or reset the stats. Marks
  /// the post as edited with a fresh `updatedAt` server timestamp.
  Future<void> updatePost(Post post) async {
    await _posts.doc(post.id).set({
      ...post.toData(),
      'createdAt': post.createdAt != null
          ? Timestamp.fromDate(post.createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePost(String id) async {
    await _posts.doc(id).delete();
  }

  /// Counts one more view on the post. The Firestore rules let anyone
  /// increment just this field, so the counter works without signing in.
  Future<void> incrementViews(String id) async {
    await _posts.doc(id).update({'views': FieldValue.increment(1)});
  }

  /// Uploads an attachment (image or video) to Storage and returns its
  /// public download URL.
  Future<String> uploadFile({
    required Uint8List bytes,
    required String name,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref('posts/$name');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }
}
