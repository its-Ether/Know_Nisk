import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// One social link slot on the profile: a custom icon image, a human
/// title, and the link itself. Any field may be empty — an empty [link]
/// makes the slot greyed-out (visible but asleep), and an empty [iconUrl]
/// falls back to the classic brand icon for the slot's title.
class SocialLink {
  const SocialLink({this.title = '', this.link = '', this.iconUrl = ''});

  /// The human name shown in the socials dialog (e.g. "GitHub").
  final String title;

  /// Where the visitor goes when they pick this slot (empty = not set).
  final String link;

  /// A custom uploaded icon image URL; empty = brand-icon fallback.
  final String iconUrl;

  factory SocialLink.fromData(Map<String, dynamic> data) => SocialLink(
        title: (data['title'] as String?) ?? '',
        link: (data['link'] as String?) ?? '',
        iconUrl: (data['iconUrl'] as String?) ?? '',
      );

  Map<String, dynamic> toData() =>
      {'title': title, 'link': link, 'iconUrl': iconUrl};

  SocialLink copyWith({String? title, String? link, String? iconUrl}) =>
      SocialLink(
        title: title ?? this.title,
        link: link ?? this.link,
        iconUrl: iconUrl ?? this.iconUrl,
      );

  /// Nothing set at all — the slot renders greyed-out and inert.
  bool get isEmpty => title.isEmpty && link.isEmpty && iconUrl.isEmpty;

  /// The slot is tappable by visitors when a link is set.
  bool get isLive => link.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is SocialLink &&
      other.title == title &&
      other.link == link &&
      other.iconUrl == iconUrl;

  @override
  int get hashCode => Object.hash(title, link, iconUrl);
}

/// The editable site content behind the Home page — the four things the
/// admin editor can change: cover, avatar, name and bio, plus the flexible
/// list of social link slots shown in the header.
class SiteContent {
  const SiteContent({
    required this.coverUrl,
    required this.avatarUrl,
    required this.name,
    required this.bio,
    this.username = '',
    this.socials = defaultSocials,
    this.updatedAt,
  });

  /// Storage URL; empty means "keep the placeholder art".
  final String coverUrl;
  final String avatarUrl;
  final String name;
  final String bio;

  /// The handle shown under the name on Home (empty = show the default).
  final String username;

  /// The social link slots (any number). The header shows the first three
  /// plus a "+N" chip when there are more; tapping the area opens the
  /// socials dialog listing them all.
  final List<SocialLink> socials;

  /// When the content was last published.
  final DateTime? updatedAt;

  /// The classic three slots, used while nothing is published yet — the
  /// same Facebook / X / GitHub faces the site has always shown.
  static const List<SocialLink> defaultSocials = [
    SocialLink(title: 'Facebook'),
    SocialLink(title: 'X'),
    SocialLink(title: 'GitHub'),
  ];

  factory SiteContent.fromData(Map<String, dynamic> data) {
    final updated = data['updated_at'];
    final rawSocials = data['socials'];
    final socials = rawSocials is List && rawSocials.isNotEmpty
        ? [
            for (final entry in rawSocials)
              if (entry is Map<String, dynamic>) SocialLink.fromData(entry),
          ]
        : defaultSocials;
    return SiteContent(
      coverUrl: (data['cover_url'] as String?) ?? '',
      avatarUrl: (data['avatar_url'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      bio: (data['bio'] as String?) ?? '',
      username: (data['username'] as String?) ?? '',
      socials: socials,
      updatedAt: updated is String ? DateTime.tryParse(updated) : null,
    );
  }

  Map<String, dynamic> toData() => {
        'cover_url': coverUrl,
        'avatar_url': avatarUrl,
        'name': name,
        'bio': bio,
        'username': username,
        'socials': [for (final social in socials) social.toData()],
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
