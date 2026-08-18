import 'package:flutter/material.dart';

import '../posts_service.dart';
import 'post_card.dart';

/// The tabs + post feed under the profile block: a tab row of `[All]` plus
/// one tab per folder, and below it the posts of the selected tab, newest
/// first. Rendered by the shared ProfileView, so Home and the admin editor
/// show exactly the same feed.
class PostsSection extends StatefulWidget {
  const PostsSection({
    super.key,
    required this.name,
    required this.avatarUrl,
    this.onPostTap,
  });

  final String name;
  final String avatarUrl;

  /// What a tap on a post does (Home: the full-post popup; the admin
  /// editor: the manage dialog). Null keeps the cards inert.
  final void Function(Post post)? onPostTap;

  @override
  State<PostsSection> createState() => _PostsSectionState();
}

class _PostsSectionState extends State<PostsSection> {
  String _selected = allTabLabel;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Post>>(
      valueListenable: PostsState.instance.posts,
      builder: (context, posts, _) {
        final folders = PostsState.instance.folders;
        // If the selected folder no longer exists (its last post deleted),
        // fall back to the catch-all tab without touching the stored value.
        final selected = folders.contains(_selected) ? _selected : allTabLabel;
        final visible = [
          for (final post in posts)
            if (selected == allTabLabel || post.folder == selected) post,
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab row — [All] first, then one tab per folder.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final folder in [allTabLabel, ...folders])
                    Expanded(
                      child: _FolderTab(
                        label: folder,
                        selected: folder == selected,
                        onTap: () => setState(() => _selected = folder),
                      ),
                    ),
                ],
              ),
            ),
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(
                  child: Text(
                    'No posts yet',
                    style: TextStyle(color: Colors.white24, fontSize: 14),
                  ),
                ),
              ),
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Colors.white12),
              PostCard(
                post: visible[i],
                name: widget.name,
                avatarUrl: widget.avatarUrl,
                onTap: widget.onPostTap == null
                    ? null
                    : () => widget.onPostTap!(visible[i]),
              ),
            ],
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}

/// A text-only tab with the same underline treatment the old placeholder
/// tabs had — labels scale down (FittedBox) so the row never overflows.
class _FolderTab extends StatelessWidget {
  const _FolderTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? Colors.white : Colors.white54,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              height: 3,
              color: selected ? Colors.blueGrey.shade300 : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }
}
