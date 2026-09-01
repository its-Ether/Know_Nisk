import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// The editable site content behind the Home page — the four things the
/// admin editor can change: cover, avatar, name and bio, plus the social
/// handle links (where the Facebook / X / GitHub icons point).
class SiteContent {
  const SiteContent({
    required this.coverUrl,
    required this.avatarUrl,
    required this.name,
    required this.bio,
    this.username = '',
    this.facebookUrl = '',
    this.xUrl = '',
    this.githubUrl = '',
    this.updatedAt,
  });

  /// Storage download URL; empty means "keep the placeholder art".
  final String coverUrl;
  final String avatarUrl;
  final String name;
  final String bio;

  /// The handle shown under the name on Home (empty = show the default).
  final String username;

  /// Where each social icon on the Home page redirects (empty = not set).
  final String facebookUrl;
  final String xUrl;
  final String githubUrl;

  /// When the content was last published (server timestamp).
  final DateTime? updatedAt;

  factory SiteContent.fromData(Map<String, dynamic> data) {
    final updated = data['updatedAt'];
    return SiteContent(
      coverUrl: (data['coverUrl'] as String?) ?? '',
      avatarUrl: (data['avatarUrl'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      facebookUrl: (data['facebookUrl'] as String?) ?? '',
      xUrl: (data['xUrl'] as String?) ?? '',
      githubUrl: (data['githubUrl'] as String?) ?? '',
      updatedAt: updated is Timestamp ? updated.toDate() : null,
    );
  }

  Map<String, dynamic> toData() => {
        'coverUrl': coverUrl,
        'avatarUrl': avatarUrl,
        'name': name,
        'bio': bio,
        'username': username,
        'facebookUrl': facebookUrl,
        'xUrl': xUrl,
        'githubUrl': githubUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}

/// In-memory site content for the widget tree, fed by the Firestore stream
/// subscribed in `main()`. Like [AuthState], it keeps Firebase out of builds
/// so the widget tests run without a Firebase app — until a subscription
/// fires, the value stays null and pages render their placeholders.
class SiteContentState {
  SiteContentState._();

  static final SiteContentState instance = SiteContentState._();

  final ValueNotifier<SiteContent?> content = ValueNotifier<SiteContent?>(null);

  /// Total site views, fed by the `stats/site` stream subscribed in `main()`.
  /// The header views counter on Home and the editor reads this live.
  final ValueNotifier<int> siteViews = ValueNotifier<int>(0);
}

/// Reads and publishes the site content document (`admin/site` in Firestore,
/// images in Storage under `images/`).
class SiteContentService {
  SiteContentService._();

  static final SiteContentService instance = SiteContentService._();

  DocumentReference<Map<String, dynamic>> get _siteDoc =>
      FirebaseFirestore.instance.collection('admin').doc('site');

  DocumentReference<Map<String, dynamic>> get _siteStatsDoc =>
      FirebaseFirestore.instance.collection('stats').doc('site');

  /// Live stream of the site content; emits null while the document is missing.
  Stream<SiteContent?> watch() {
    return _siteDoc.snapshots().map((snapshot) {
      final data = snapshot.data();
      return data == null ? null : SiteContent.fromData(data);
    });
  }

  /// Live stream of the total site views (0 while the stats doc is missing).
  Stream<int> watchSiteViews() {
    return _siteStatsDoc.snapshots().map(
          (snapshot) =>
              ((snapshot.data()?['views'] as num?) ?? 0).toInt(),
        );
  }

  /// Counts one more view of the site. Lives in its own `stats/site` doc so
  /// publishing the site content can never reset it; the rules let anyone
  /// increment just this field (like a post's view counter).
  Future<void> incrementSiteView() async {
    await _siteStatsDoc.set(
      {'views': FieldValue.increment(1)},
      SetOptions(merge: true),
    );
  }

  /// Uploads an image to Storage and returns its public download URL.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String name,
    required String contentType,
  }) async {
    final ref = FirebaseStorage.instance.ref('images/$name');
    await ref.putData(bytes, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  /// Publishes [content] to `admin/site` — it goes live on the Home page
  /// immediately (public read rule, and the Home page listens for changes).
  Future<void> publish(SiteContent content) async {
    await _siteDoc.set(content.toData());
  }
}
