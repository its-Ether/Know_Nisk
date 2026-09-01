import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format_utils.dart';
import '../posts_service.dart';
import '../site_content_service.dart';
import 'posts_section.dart';

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
    this.onUsernameTap,
    this.onNameEditDone,
    this.onBioEditDone,
    this.onUsernameEditDone,
    this.nameController,
    this.bioController,
    this.usernameController,
    this.editingName = false,
    this.editingBio = false,
    this.editingUsername = false,
    this.coverBytes,
    this.avatarBytes,
    this.publishButton,
    this.onSocialTap,
    this.onPostTap,
  });

  final SiteContent? content;

  /// Edit hooks (null on the public Home page).
  final VoidCallback? onCoverTap;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;
  final VoidCallback? onBioTap;
  final VoidCallback? onUsernameTap;
  final VoidCallback? onNameEditDone;
  final VoidCallback? onBioEditDone;
  final VoidCallback? onUsernameEditDone;

  /// Editor state.
  final TextEditingController? nameController;
  final TextEditingController? bioController;
  final TextEditingController? usernameController;
  final bool editingName;
  final bool editingBio;
  final bool editingUsername;
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

  /// What a tap on a post in the feed does — the Home page opens the
  /// full-post popup, the admin editor opens its manage dialog. Null keeps
  /// the post cards inert.
  final void Function(Post post)? onPostTap;

  static const double _coverHeight = 160;
  static const double _avatarRadius = 56;

  /// Below this padded header width the social icons drop to their own
  /// right-aligned line instead of sharing the row with the profile block.
  /// Kept low enough that every normal phone width (>= ~332px screen, which
  /// is ~300px of padded header width) stays on ONE line — the icons stay
  /// level with the profile name instead of shifting down; only ultra-narrow
  /// screens fall back to the stacked layout so nothing ever overflows.
  static const double _headerOneLineMinWidth = 300;

  /// Vertical lift that aligns a bottom-anchored element with the profile
  /// name — used for both the views counter and the social icons so they
  /// sit level with the name.
  static const double _nameAlignLift = 28;

  static const String _fallbackBio =
      'Aspiring developer and creator building my presence online, '
      'one project at a time. Exploring new technologies, design, '
      'and things that feel good to use. More coming soon.';

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

    // Row 2: column 1 (avatar, name, username) plus the views counter —
    // 18px gap; the counter is bottom-aligned with a lift so it sits
    // beside the profile name (the row's bottom is the username's bottom,
    // the name sits just above it). Fixed relative to the column, so the
    // alignment holds at any width.
    final row2 = Row(
      mainAxisSize: MainAxisSize.min,
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
                        ? const AssetImage('assets/avatar_placeholder.png')
                        : NetworkImage(avatarUrl),
                // A failed load keeps the placeholder fallback.
                onBackgroundImageError: avatarBytes != null ||
                        avatarUrl.isNotEmpty
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
            if (editingUsername && usernameController != null)
              SizedBox(
                width: 220,
                child: TextField(
                  controller: usernameController,
                  autofocus: true,
                  textAlign: TextAlign.center,
                  cursorColor: Colors.blue,
                  style: GoogleFonts.courierPrime(
                    fontSize: 13,
                    color: Colors.blue,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Nisk.Niship',
                    hintStyle: GoogleFonts.courierPrime(
                      fontSize: 13,
                      color: Colors.white24,
                    ),
                  ),
                  onTapOutside: (_) => onUsernameEditDone?.call(),
                ),
              )
            else
              GestureDetector(
                onTap: onUsernameTap,
                child: Text(
                  (content?.username.isNotEmpty ?? false)
                      ? content!.username
                      : 'Nisk.Niship',
                  style: GoogleFonts.courierPrime(
                    fontSize: 13,
                    color: Colors.blue,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 18),
        // The live site views counter — fed by the stats stream in main();
        // until the first count arrives it reads 0. A compact pill with no
        // "views" label so it reads as its own chip beside the name.
        Padding(
          padding: const EdgeInsets.only(bottom: _nameAlignLift),
          child: ValueListenableBuilder<int>(
            valueListenable: SiteContentState.instance.siteViews,
            builder: (context, views, _) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.visibility,
                    size: 14,
                    color: Colors.white70,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    formatCount(views),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    // Row 1: the social handle icons. On Home they open their published
    // links in a new tab; in the editor (when onSocialTap is set) a tap
    // opens the link editor popup instead. The admin editor also appends
    // its Publish control to this row while unsaved changes exist.
    final socialIcons = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SocialIcon(
          icon: FontAwesomeIcons.facebookF,
          label: 'Facebook',
          url: content?.facebookUrl ?? '',
          onTap: onSocialTap == null ? null : () => onSocialTap!('facebook'),
        ),
        _SocialIcon(
          icon: FontAwesomeIcons.xTwitter,
          label: 'X',
          url: content?.xUrl ?? '',
          onTap: onSocialTap == null ? null : () => onSocialTap!('x'),
        ),
        _SocialIcon(
          icon: FontAwesomeIcons.github,
          label: 'GitHub',
          url: content?.githubUrl ?? '',
          onTap: onSocialTap == null ? null : () => onSocialTap!('github'),
        ),
        if (publishButton != null)
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: publishButton!,
          ),
      ],
    );

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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      // Wide enough: one line — row 2 (profile block) on the
                      // left, row 1 (social icons) pushed to the far right,
                      // aligned with the profile name. This holds at every
                      // normal phone width too, so the icons never shift
                      // down on mobile. Only ultra-narrow widths fall back
                      // to a stacked layout so nothing overflows.
                      if (constraints.maxWidth >= _headerOneLineMinWidth) {
                        return Row(
                          // Bottom-aligned with the same lift as the views
                          // counter, so the icons sit level with the name
                          // (not centered mid-column, not touching the bio).
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            row2,
                            // The icons get all remaining width and stay
                            // pinned to the far right. If the row gets tight
                            // (phones), the FittedBox scales them down a
                            // notch instead of overflowing — so the icons
                            // never drop off the profile-name line.
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: EdgeInsets.only(
                                    bottom: _nameAlignLift,
                                  ),
                                  child: socialIcons,
                                ),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          row2,
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: socialIcons,
                          ),
                        ],
                      );
                    },
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
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.4,
                      color: Colors.white70,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Write a bio…',
                      hintStyle: const TextStyle(
                        fontSize: 15,
                        color: Colors.white24,
                      ),
                    ),
                    onTapOutside: (_) => onBioEditDone?.call(),
                  )
                else
                  _ExpandableBio(
                    bio: bio,
                    // On Home there is no edit hook, so a long bio becomes
                    // tappable to expand; in the editor the tap edits.
                    toggleable: onBioTap == null,
                    onEditTap: onBioTap,
                  ),
                const SizedBox(height: 12),
                Text(
                  updatedOn,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF2E7D32), // dark green — N1SK
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          // Folder tabs + post feed — [All] plus one tab per folder.
          PostsSection(
            name: name,
            avatarUrl: avatarUrl,
            onPostTap: onPostTap,
          ),
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

  final FaIconData icon;
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
                        child: FaIcon(icon, size: 22, color: Colors.white70),
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

/// The profile bio. On the public Home page a bio longer than 5 lines is
/// clamped to 5 lines with an ellipsis and tapping it expands/collapses the
/// full text; shorter bios render plain. In the editor (which passes
/// [onEditTap]) the clamp still applies visually, but a tap enters edit
/// mode exactly as before.
class _ExpandableBio extends StatefulWidget {
  const _ExpandableBio({
    required this.bio,
    this.toggleable = false,
    this.onEditTap,
  });

  final String bio;

  /// Home mode: a long bio can be expanded/collapsed by tapping it.
  final bool toggleable;

  /// Editor mode: what a tap does instead of expanding.
  final VoidCallback? onEditTap;

  @override
  State<_ExpandableBio> createState() => _ExpandableBioState();
}

class _ExpandableBioState extends State<_ExpandableBio> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Same face and size as the post text: plain default font at 15px
    // (height 1.4, white70), identical to the feed card body — N1SK asked
    // for the bio to be the post font at the exact same size.
    final style = const TextStyle(
      fontSize: 15,
      height: 1.4,
      color: Colors.white70,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        // Measure with the same style and width the Text will use, capped
        // at 5 lines — a bio that fits stays plain, one that doesn't clamps.
        final painter = TextPainter(
          text: TextSpan(text: widget.bio, style: style),
          maxLines: 5,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);
        final expandable = painter.didExceedMaxLines;
        final maxLines = expandable && !_expanded ? 5 : null;
        final hasAction = widget.onEditTap != null ||
            (widget.toggleable && expandable);
        final text = Text(
          widget.bio,
          style: style,
          maxLines: maxLines,
          overflow: maxLines == 5 ? TextOverflow.ellipsis : TextOverflow.visible,
        );
        if (!hasAction) return text;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (widget.toggleable && expandable) {
              setState(() => _expanded = !_expanded);
            } else {
              widget.onEditTap?.call();
            }
          },
          child: text,
        );
      },
    );
  }
}
