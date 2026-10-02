import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Storage URL; empty means "keep the placeholder art".
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

  /// When the content was last published.
  final DateTime? updatedAt;

  factory SiteContent.fromData(Map<String, dynamic> data) {
    final updated = data['updated_at'];
    return SiteContent(
      coverUrl: (data['cover_url'] as String?) ?? '',
      avatarUrl: (data['avatar_url'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      facebookUrl: (data['facebook_url'] as String?) ?? '',
      xUrl: (data['x_url'] as String?) ?? '',
      githubUrl: (data['github_url'] as String?) ?? '',
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
    );
  }

  Map<String, dynamic> toData() => {
        'cover_url': coverUrl,
        'avatar_url': avatarUrl,
        'name': name,
        'bio': bio,
        'username': username,
        'facebook_url': facebookUrl,
        'x_url': xUrl,
        'github_url': githubUrl,
      };
}

/// In-memory site content for the widget tree, fed by the Supabase realtime
/// stream subscribed in `main()`. Like [AuthState], it keeps the backend out
/// of builds so the widget tests run without a database — until a
/// subscription fires, the value stays null and pages render their
/// placeholders.
class SiteContentState {
  SiteContentState._();

  static final SiteContentState instance = SiteContentState._();

  final ValueNotifier<SiteContent?> content = ValueNotifier<SiteContent?>(null);

  /// Total site views, fed by the `site_stats` stream subscribed in `main()`.
  /// The header views counter on Home and the editor reads this live.
  final ValueNotifier<int> siteViews = ValueNotifier<int>(0);
}

/// Reads and publishes the site content (the `site_content` row in Postgres,
/// images in the `images` storage bucket).
class SiteContentService {
  SiteContentService._();

  static final SiteContentService instance = SiteContentService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Live stream of the site content; emits null while the row is empty
  /// (then the pages show their built-in placeholder art).
  Stream<SiteContent?> watch() {
    return _client
        .from('site_content')
        .stream(primaryKey: ['id'])
        .eq('id', 'site')
        .map((rows) => rows.isEmpty ? null : SiteContent.fromData(rows.first));
  }

  /// Live stream of the total site views (0 while the stats row is missing).
  Stream<int> watchSiteViews() {
    return _client
        .from('site_stats')
        .stream(primaryKey: ['id'])
        .eq('id', 'site')
        .map((rows) =>
            rows.isEmpty ? 0 : ((rows.first['views'] as num?) ?? 0).toInt());
  }

  /// Counts one more view of the site. The server only allows "+1" —
  /// a visitor can pull the vending machine lever, nothing more.
  Future<void> incrementSiteView() async {
    await _client.rpc('increment_site_views');
  }

  /// Uploads an image to the `images` bucket and returns its public URL.
  Future<String> uploadImage({
    required Uint8List bytes,
    required String name,
    required String contentType,
  }) async {
    await _client.storage.from('images').uploadBinary(
          name,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );
    return _client.storage.from('images').getPublicUrl(name);
  }

  /// Publishes [content] to `site_content` (upserting the single 'site'
  /// row) — it goes live on the Home page immediately (public read policy,
  /// and the Home page listens for changes).
  Future<void> publish(SiteContent content) async {
    await _client.from('site_content').upsert({
      'id': 'site',
      ...content.toData(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
