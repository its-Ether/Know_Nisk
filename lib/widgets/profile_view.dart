import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../site_content_service.dart';

/// The Home page's profile block, shared verbatim by the Home page and the
/// admin editor — one source of layout, so the editor is always an exact
/// replica of Home.
///
/// When the optional edit hooks are provided the block becomes editable:
/// tapping the cover/avatar/[name]/[bio] triggers the corresponding
/// callback, and an in-edit name/bio renders as a TextField styled exactly
/// like the static text. Without the hooks it renders read-only, which is
/// how the public Home page uses it.
class ProfileView extends StatelessWidget {
  const ProfileView({
    super.key,
    required this.content,
    this.onCoverTap,
    this.onAvatarTap,
    this.onNameTap,
    this.onBioTap,
    this.onNameEditDone,
    this.onBioEditDone,
    this.nameController,
    this.bioController,
    this.editingName = false,
    this.editingBio = false,
    this.coverBytes,
    this.avatarBytes,
    this.publishButton,
    this.onSocialTap,
  });

  final SiteContent? content;

  /// Edit hooks (null on the public Home page).
  final VoidCallback? onCoverTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;
  final VoidCallback? onBioTap;
  final VoidCallback? onNameEditDone;
  final VoidCallback? onBioEditDone;

  /// Editor state.
  final TextEditingController? nameController;
  final TextEditingController? bioController;
  final bool editingName;
  final bool editingBio;
  final Uint8List? coverBytes;
  final Uint8List? avatarBytes;

  /// Optional Publish control, rendered at the end of the social icons row.
  /// Only the admin editor passes one (and only while there are unsaved
  /// changes), so the row stays a pixel replica of Home otherwise.
  final Widget? publishButton;

  /// Editor hook — tapping a social icon calls it with its key
  /// (`'facebook'` | `'x'` | `'github'`). Null on the public Home page,
  /// where the icons instead open their published links in a new tab.
  final void Function(String social)? onSocialTap;

  static const double _coverHeight = 200;
  static const double _avatarRadius = 56;

  static const String _fallbackBio =
      'Aspiring developer and creator building my presence online, '
      'one project at a time. Exploring new technologies, design, '
      'and things that feel good to use. More coming soon.';

  static const List<String> _tabs = ['tab1', 'tab2', 'tab3', 'tab4'];

  /// Placeholder icons for the tabs — swapped for real ones later.
  static const List<IconData> _tabIcons = [
    Icons.article_outlined,
    Icons.photo_outlined,
    Icons.play_circle_outline,
    Icons.star_outline,
  ];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDate(DateTime date) {
    return 'Updated on: ${_months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final name = content?.name ?? 'N1SK';
    // An empty published bio (or no doc yet) shows the approved placeholder —
    // a blank bio is invisible and untappable in the editor, so the user could
    // never fix it.
    final bio = (content?.bio == null || content!.bio.isEmpty)
        ? _fallbackBio
        : content!.bio;
    final coverUrl = content?.coverUrl ?? '';
    final avatarUrl = content?.avatarUrl ?? '';
    // The date the content was last published; today until it is.
    final updatedOn =
        content?.updatedAt != null
            ? _formatDate(content!.updatedAt!)
            : _formatDate(DateTime.now());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Cover + header in one Stack. The cover is pinned to the stack's
          // top; the header row is pushed down by (coverHeight - avatarRadius)
          // so the avatar overlaps the cover's bottom edge. The row's natural
          // height drives the stack height, so the profile block below starts
          // right under the username — no negative margins, no phantom gap.
          Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onCoverTap,
                  child: coverBytes != null
                      ? Image.memory(
                          coverBytes!,
                          height: _coverHeight,
                          fit: BoxFit.cover,
                        )
                      : coverUrl.isEmpty
                          ? Image.asset(
                              'assets/cover_placeholder.png',
                              height: _coverHeight,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              coverUrl,
                              height: _coverHeight,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/cover_placeholder.png',
                                height: _coverHeight,
                                fit: BoxFit.cover,
                              ),
                            ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: _coverHeight - _avatarRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    // Keeps the social icons aligned with the bottom of column 1.
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Column 1: avatar, name and username, centered.
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: onAvatarTap,
                            child: CircleAvatar(
                              radius: _avatarRadius,
                              backgroundColor: Colors.white10,
                              backgroundImage: avatarBytes != null
                                  ? MemoryImage(avatarBytes!)
                                  : avatarUrl.isEmpty
                                      ? const AssetImage(
                                          'assets/avatar_placeholder.png',
                                        )
                                      : NetworkImage(avatarUrl),
                              // A failed load keeps the placeholder fallback.
                              onBackgroundImageError:
                                  avatarBytes != null || avatarUrl.isNotEmpty
                                      ? (_, _) {}
                                      : null,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (editingName && nameController != null)
                            SizedBox(
                              width: 220,
                              child: TextField(
                                controller: nameController,
                                autofocus: true,
                                textAlign: TextAlign.center,
                                cursorColor: Colors.white70,
                                style: const TextStyle(
                                  fontFamily: 'Sekuya',
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                                decoration: InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                  hintText: 'Name',
                                  hintStyle: const TextStyle(
                                    fontFamily: 'Sekuya',
                                    fontSize: 28,
                                    color: Colors.white24,
                                  ),
                                ),
                                onTapOutside: (_) => onNameEditDone?.call(),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: onNameTap,
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontFamily: 'Sekuya',
                                  fontSize: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Nisk.Niship',
                            style: GoogleFonts.courierPrime(
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Social media handle icons. On Home they open their
                      // published links in a new tab; in the editor (when
                      // onSocialTap is set) a tap opens the link editor
                      // popup instead. The admin editor also appends its
                      // Publish control to this row while unsaved changes
                      // exist.
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SocialIcon(
                              icon: FontAwesomeIcons.facebookF,
                              label: 'Facebook',
                              url: content?.facebookUrl ?? '',
                              onTap: onSocialTap == null
                                  ? null
                                  : () => onSocialTap!('facebook'),
                            ),
                            _SocialIcon(
                              icon: FontAwesomeIcons.xTwitter,
                              label: 'X',
                              url: content?.xUrl ?? '',
                              onTap: onSocialTap == null
                                  ? null
                                  : () => onSocialTap!('x'),
                            ),
                            _SocialIcon(
                              icon: FontAwesomeIcons.github,
                              label: 'GitHub',
                              url: content?.githubUrl ?? '',
                              onTap: onSocialTap == null
                                  ? null
                                  : () => onSocialTap!('github'),
                            ),
                            if (publishButton != null)
                              Padding(
                                padding: const EdgeInsets.only(left: 16),
                                child: publishButton!,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Full-width profile block, outside column 1.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (editingBio && bioController != null)
                  TextField(
                    controller: bioController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: null,
                    cursorColor: Colors.white70,
                    style: GoogleFonts.comfortaa(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Write a bio…',
                      hintStyle: GoogleFonts.comfortaa(
                        fontSize: 15,
                        color: Colors.white24,
                      ),
                    ),
                    onTapOutside: (_) => onBioEditDone?.call(),
                  )
                else
                  GestureDetector(
                    onTap: onBioTap,
                    child: Text(
                      bio,
                      style: GoogleFonts.comfortaa(
                        fontSize: 15,
                        height: 1.4,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  updatedOn,
                  style: const TextStyle(fontSize: 15, color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.visibility, size: 18, color: Colors.white70),
                    SizedBox(width: 6),
                    Text(
                      '0 views',
                      style: TextStyle(fontSize: 15, color: Colors.white70),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Tabs.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (var i = 0; i < _tabs.length; i++)
                  Expanded(
                    child: _TabLabel(
                      label: _tabs[i],
                      icon: _tabIcons[i],
                      selected: i == 0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SocialIcon extends StatelessWidget {
  const _SocialIcon({
    required this.icon,
    required this.label,
    this.url,
    this.onTap,
  });

  final IconData icon;
  final String label;

  /// The published link on the public Home page (empty = not set).
  final String? url;

  /// Editor mode: what tapping the icon does instead of opening [url].
  final VoidCallback? onTap;

  /// Opens [url] in a new browser tab. Adds https:// when the admin typed a
  /// bare domain; failures are ignored so a bad link never breaks the page.
  Future<void> _openLink() async {
    try {
      var target = url!.trim();
      if (!target.startsWith('http://') && !target.startsWith('https://')) {
        target = 'https://$target';
      }
      await launchUrl(Uri.parse(target), webOnlyWindowName: '_blank');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final child = Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Tooltip(
        message: label,
        child: Icon(icon, size: 22, color: Colors.white70),
      ),
    );
    final editable = onTap != null;
    final hasLink = url != null && url!.isNotEmpty;
    if (!editable && !hasLink) return child;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? _openLink,
        child: child,
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.label,
    required this.icon,
    required this.selected,
  });

  final String label;
  final IconData icon;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: Colors.blue),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 3,
            color: selected ? Colors.blueGrey.shade300 : Colors.transparent,
          ),
        ],
      ),
    );
  }
}
