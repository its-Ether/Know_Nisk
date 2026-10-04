import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../image_utils.dart';
import '../posts_service.dart';
import '../site_content_service.dart';
import '../widgets/profile_view.dart';
import '../widgets/socials_dialog.dart';
import 'post_composer_page.dart';

/// Admin editor — served at `/admin-editor`, reachable only while signed in
/// (the router redirects logged-out visitors to the Home screen).
///
/// The page IS the Home page: the same [ProfileView] replica, nothing added.
/// Tapping the cover, avatar, name or bio makes that element editable (the
/// name/bio swap in place to identically-styled text fields; the images open
/// the picker); tapping the social icons area opens the socials dialog,
/// where every slot's icon, title and link can be edited at once. A **Publish** pill appears in the social icons row only once
/// something has changed — it uploads new images to the Supabase `images`
/// bucket and writes the `site_content` row, which the public Home page
/// picks up live.
class AdminEditorPage extends StatefulWidget {
  const AdminEditorPage({super.key});

  @override
  State<AdminEditorPage> createState() => _AdminEditorPageState();
}

class _AdminEditorPageState extends State<AdminEditorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _editingName = false;
  bool _editingBio = false;
  bool _editingUsername = false;

  /// Newly picked images, null until the admin changes them.
  Uint8List? _coverBytes;
  Uint8List? _avatarBytes;

  /// Unsaved social slot edits (the full editable list); null = unchanged,
  /// so the published list shows. Set when the socials dialog returns a
  /// changed list — the Publish pill appears, and publish uploads any
  /// newly picked custom icons and pushes the list live.
  List<SocialEdit>? _pendingSocials;

  /// True once anything has been edited — shows the Publish pill.
  bool _dirty = false;
  bool _publishing = false;

  /// Filled once from the current site content, so typing is never clobbered
  /// when the content stream emits (e.g. right after a publish).
  bool _fieldsSynced = false;

  /// The text values at sync time. A controller can notify on selection or
  /// focus changes without any text edit, so `_dirty` must only flip when the
  /// text actually diverges from these.
  String _syncedName = '';
  String _syncedBio = '';
  String _syncedUsername = '';

  /// True while programmatically filling the controllers — don't mark dirty.
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _fillFieldsOnce();
    SiteContentState.instance.content.addListener(_onContentChanged);
    _nameController.addListener(_onTextChanged);
    _bioController.addListener(_onTextChanged);
    _usernameController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    SiteContentState.instance.content.removeListener(_onContentChanged);
    _nameController.dispose();
    _bioController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _onContentChanged() {
    _fillFieldsOnce();
    // Refresh the cover/avatar previews when content changes.
    if (mounted) setState(() {});
  }

  void _fillFieldsOnce() {
    if (_fieldsSynced) return;
    final content = SiteContentState.instance.content.value;
    if (content == null) return;
    _fieldsSynced = true;
    _hydrating = true;
    _nameController.text = content.name;
    _bioController.text = content.bio;
    _usernameController.text = content.username;
    _hydrating = false;
    _syncedName = _nameController.text;
    _syncedBio = _bioController.text;
    _syncedUsername = _usernameController.text;
  }

  void _onTextChanged() {
    if (_hydrating) return;
    final edited =
        _nameController.text != _syncedName ||
        _bioController.text != _syncedBio ||
        _usernameController.text != _syncedUsername;
    // Rebuild so the Publish pill appears as soon as something changes.
    if (edited && !_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickCover() async {
    final bytes = await _pickImage();
    if (bytes == null) return;
    setState(() {
      _coverBytes = bytes;
      _dirty = true;
    });
  }

  Future<void> _pickAvatar() async {
    final bytes = await _pickImage();
    if (bytes == null) return;
    setState(() {
      _avatarBytes = bytes;
      _dirty = true;
    });
  }

  Future<Uint8List?> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    return picked?.readAsBytes();
  }

  /// Opens the socials dialog: every slot's icon, title and link editable
  /// at once, plus add/remove. Done returns the full list; it only marks
  /// the page dirty (so the Publish pill appears) when something actually
  /// changed — new icons, different links, or a different slot count.
  Future<void> _editSocials() async {
    final current = SiteContentState.instance.content.value;
    final initial = _pendingSocials != null
        ? [for (final edit in _pendingSocials!) edit.link]
        : current?.socials ?? SiteContent.defaultSocials;
    final result = await showDialog<List<SocialEdit>>(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => SocialsDialog.editor(socials: initial),
    );
    if (result == null || !mounted) return;
    final links = [for (final edit in result) edit.link];
    final changed = result.any((edit) => edit.newIconBytes != null) ||
        !_sameList(links, initial);
    if (!changed) return;
    setState(() {
      _pendingSocials = result;
      _dirty = true;
    });
  }

  /// Element-wise comparison of two slot lists (titles, links, icons).
  bool _sameList(List<SocialLink> a, List<SocialLink> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Uploads a newly picked custom social icon (downscaled to 256px — the
  /// icons render at 22px, so 256 covers even the densest screens) and
  /// returns its public URL.
  Future<String> _uploadIcon(Uint8List bytes) async {
    final prepared = prepareImageForUpload(bytes, maxWidth: 256);
    return SiteContentService.instance.uploadImage(
      bytes: prepared.bytes,
      name: 'icon_${DateTime.now().millisecondsSinceEpoch}.${prepared.ext}',
      contentType: prepared.contentType,
    );
  }

  Future<void> _publish() async {
    setState(() {
      _publishing = true;
      _editingName = false;
      _editingBio = false;
    });
    try {
      final service = SiteContentService.instance;
      final current = SiteContentState.instance.content.value;

      var coverUrl = current?.coverUrl ?? '';
      if (_coverBytes != null) {
        final prepared = prepareImageForUpload(_coverBytes!, maxWidth: 1200);
        coverUrl = await service.uploadImage(
          bytes: prepared.bytes,
          name:
              'cover_${DateTime.now().millisecondsSinceEpoch}.${prepared.ext}',
          contentType: prepared.contentType,
        );
      }

      var avatarUrl = current?.avatarUrl ?? '';
      if (_avatarBytes != null) {
        final prepared = prepareImageForUpload(_avatarBytes!, maxWidth: 512);
        avatarUrl = await service.uploadImage(
          bytes: prepared.bytes,
          name:
              'avatar_${DateTime.now().millisecondsSinceEpoch}.${prepared.ext}',
          contentType: prepared.contentType,
        );
      }

      // The social slots: keep the published list, or apply the pending
      // edits — uploading any newly picked custom icons (the avatar
      // pipeline, shrunk to icon size) and pointing the slots at them.
      final List<SocialLink> socials;
      if (_pendingSocials != null) {
        socials = [
          for (final edit in _pendingSocials!)
            if (edit.newIconBytes != null)
              edit.link.copyWith(
                iconUrl: await _uploadIcon(edit.newIconBytes!),
              )
            else
              edit.link,
        ];
      } else {
        socials = current?.socials ?? SiteContent.defaultSocials;
      }

      await service.publish(
        SiteContent(
          coverUrl: coverUrl,
          avatarUrl: avatarUrl,
          name: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          username: _usernameController.text.trim(),
          socials: socials,
        ),
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _coverBytes = null;
        _avatarBytes = null;
        _pendingSocials = null;
        // What was just published is now the baseline.
        _syncedName = _nameController.text;
        _syncedBio = _bioController.text;
        _syncedUsername = _usernameController.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Published — the Home page now shows this.'),
          backgroundColor: const Color(0xFF111111),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.blue,
            onPressed: () => context.go('/'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Publish failed: $e', style: const TextStyle(color: Colors.redAccent)),
          backgroundColor: const Color(0xFF111111),
        ),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// Opens the post composer for a brand-new post (the floating pen).
  Future<void> _openComposer() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const PostComposerPage(),
      ),
    );
  }

  /// Post taps in the editor open the manage dialog instead of the viewer:
  /// edit the post in the composer, delete it, or copy its share link.
  Future<void> _managePost(Post post) async {
    final action = await showDialog<String>(
      context: context,
      builder: (_) => _PostManageDialog(post: post),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'edit':
        await Navigator.push(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => PostComposerPage(existing: post),
          ),
        );
      case 'delete':
        await _confirmDelete(post);
      case 'copy':
        final url = Uri.base.replace(path: '/post/${post.id}').toString();
        try {
          await Clipboard.setData(ClipboardData(text: url));
        } catch (_) {}
        if (mounted) _snack('Link copied');
    }
  }

  Future<void> _confirmDelete(Post post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white12),
        ),
        title: const Text(
          'Delete post?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: const Text(
          "This removes the post from the site. It can't be undone.",
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Delete',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await PostsService.instance.deletePost(post.id);
      if (mounted) _snack('Post deleted');
    } catch (e) {
      if (mounted) _snack('Delete failed: $e', error: true);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: error ? const TextStyle(color: Colors.redAccent) : null,
        ),
        backgroundColor: const Color(0xFF111111),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = SiteContentState.instance.content.value;
    return Scaffold(
      // The only extras on the page — the Publish pill rides in the social
      // icons row and appears only while there are unsaved changes, and the
      // floating pen opens the post composer — so the clean editor is a
      // pixel replica of Home.
      floatingActionButton: FloatingActionButton(
        onPressed: _openComposer,
        shape: const CircleBorder(),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        tooltip: 'New post',
        child: const Icon(Icons.edit),
      ),
      body: ProfileView(
        content: content,
        onCoverTap: _pickCover,
        onAvatarTap: _pickAvatar,
        onNameTap: () => setState(() => _editingName = true),
        onBioTap: () => setState(() => _editingBio = true),
        onUsernameTap: () => setState(() => _editingUsername = true),
        onNameEditDone: () => setState(() => _editingName = false),
        onBioEditDone: () => setState(() => _editingBio = false),
        onUsernameEditDone: () => setState(() => _editingUsername = false),
        nameController: _nameController,
        bioController: _bioController,
        usernameController: _usernameController,
        editingName: _editingName,
        editingBio: _editingBio,
        editingUsername: _editingUsername,
        coverBytes: _coverBytes,
        avatarBytes: _avatarBytes,
        onSocialsTap: _editSocials,
        onPostTap: _managePost,
        publishButton: _dirty || _publishing
            ? _PublishButton(
                publishing: _publishing,
                onPressed: _publish,
              )
            : null,
      ),
    );
  }
}

/// The small admin dialog for a published post — edit, delete or copy its
/// share link. Shown instead of the viewer popup because the editor is the
/// admin's workspace, not a reader's.
class _PostManageDialog extends StatelessWidget {
  const _PostManageDialog({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text(
        'Post',
        style: TextStyle(color: Colors.white, fontSize: 17),
      ),
      content: SizedBox(
        width: 320,
        child: Text(
          post.text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, 'copy'),
          child: const Text('Copy link', style: TextStyle(color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, 'delete'),
          child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, 'edit'),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// The white X-style Publish pill shown in the social icons row while the
/// editor has unsaved changes; a small spinner replaces the label while a
/// publish is in flight.
class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.publishing, required this.onPressed});

  final bool publishing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: publishing ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minimumSize: const Size(0, 32),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
      ),
      child: publishing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.black,
              ),
            )
          : const Text(
              'Publish',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
    );
  }
}

