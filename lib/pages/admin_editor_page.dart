import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../site_content_service.dart';
import '../widgets/profile_view.dart';

/// Admin editor — served at `/admin-editor`, reachable only while signed in
/// (the router redirects logged-out visitors to the Home screen).
///
/// The page IS the Home page: the same [ProfileView] replica, nothing added.
/// Tapping the cover, avatar, name or bio makes that element editable (the
/// name/bio swap in place to identically-styled text fields; the images open
/// the picker); tapping a social icon opens a popup to set where that icon
/// redirects. A **Publish** pill appears in the social icons row only once
/// something has changed — it uploads new images to Firebase Storage and
/// writes `admin/site` in Firestore, which the public Home page picks up live.
class AdminEditorPage extends StatefulWidget {
  const AdminEditorPage({super.key});

  @override
  State<AdminEditorPage> createState() => _AdminEditorPageState();
}

class _AdminEditorPageState extends State<AdminEditorPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  bool _editingName = false;
  bool _editingBio = false;

  /// Newly picked images, null until the admin changes them.
  Uint8List? _coverBytes;
  Uint8List? _avatarBytes;

  /// Unsaved social handle links, keyed by `'facebook' | 'x' | 'github'`;
  /// seeded from the published content and updated by the link popup.
  final Map<String, String> _pendingLinks = {'facebook': '', 'x': '', 'github': ''};

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

  /// True while programmatically filling the controllers — don't mark dirty.
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _fillFieldsOnce();
    SiteContentState.instance.content.addListener(_onContentChanged);
    _nameController.addListener(_onTextChanged);
    _bioController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    SiteContentState.instance.content.removeListener(_onContentChanged);
    _nameController.dispose();
    _bioController.dispose();
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
    _hydrating = false;
    _syncedName = _nameController.text;
    _syncedBio = _bioController.text;
    _pendingLinks['facebook'] = content.facebookUrl;
    _pendingLinks['x'] = content.xUrl;
    _pendingLinks['github'] = content.githubUrl;
  }

  void _onTextChanged() {
    if (_hydrating) return;
    final edited =
        _nameController.text != _syncedName ||
        _bioController.text != _syncedBio;
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

  /// Opens the link-editing popup for the tapped social icon. Saving a link
  /// that differs from what's currently pending marks the page dirty so the
  /// Publish pill appears.
  Future<void> _editSocialLink(String social) async {
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => _SocialLinkDialog(
        icon: _socialIcons[social]!,
        label: _socialLabels[social]!,
        initialLink: _pendingLinks[social] ?? '',
      ),
    );
    if (saved == null || saved == (_pendingLinks[social] ?? '')) return;
    setState(() {
      _pendingLinks[social] = saved;
      _dirty = true;
    });
  }

  static const Map<String, IconData> _socialIcons = {
    'facebook': FontAwesomeIcons.facebookF,
    'x': FontAwesomeIcons.xTwitter,
    'github': FontAwesomeIcons.github,
  };

  static const Map<String, String> _socialLabels = {
    'facebook': 'Facebook',
    'x': 'X',
    'github': 'GitHub',
  };

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
        final prepared = _prepareForUpload(_coverBytes!, maxWidth: 1200);
        coverUrl = await service.uploadImage(
          bytes: prepared.bytes,
          name:
              'cover_${DateTime.now().millisecondsSinceEpoch}.${prepared.ext}',
          contentType: prepared.contentType,
        );
      }

      var avatarUrl = current?.avatarUrl ?? '';
      if (_avatarBytes != null) {
        final prepared = _prepareForUpload(_avatarBytes!, maxWidth: 512);
        avatarUrl = await service.uploadImage(
          bytes: prepared.bytes,
          name:
              'avatar_${DateTime.now().millisecondsSinceEpoch}.${prepared.ext}',
          contentType: prepared.contentType,
        );
      }

      await service.publish(
        SiteContent(
          coverUrl: coverUrl,
          avatarUrl: avatarUrl,
          name: _nameController.text.trim(),
          bio: _bioController.text.trim(),
          facebookUrl: _pendingLinks['facebook'] ?? '',
          xUrl: _pendingLinks['x'] ?? '',
          githubUrl: _pendingLinks['github'] ?? '',
        ),
      );
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _coverBytes = null;
        _avatarBytes = null;
        // What was just published is now the baseline.
        _syncedName = _nameController.text;
        _syncedBio = _bioController.text;
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

  /// Downscales a picked image for upload and re-encodes it — JPEG for
  /// photos (small uploads), PNG kept for small originals with transparency.
  ({Uint8List bytes, String ext, String contentType}) _prepareForUpload(
    Uint8List bytes, {
    required int maxWidth,
  }) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return (bytes: bytes, ext: 'jpg', contentType: 'image/jpeg');
    }
    final needsResize = decoded.width > maxWidth;
    final image = needsResize
        ? img.copyResize(decoded, width: maxWidth)
        : decoded;
    final keepPng = !needsResize && _isPng(bytes);
    if (keepPng) {
      return (
        bytes: Uint8List.fromList(img.encodePng(image)),
        ext: 'png',
        contentType: 'image/png',
      );
    }
    return (
      bytes: Uint8List.fromList(img.encodeJpg(image, quality: 85)),
      ext: 'jpg',
      contentType: 'image/jpeg',
    );
  }

  /// True when [bytes] start with the PNG signature (`89 50 4E 47`).
  bool _isPng(Uint8List bytes) {
    return bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
  }

  @override
  Widget build(BuildContext context) {
    final content = SiteContentState.instance.content.value;
    return Scaffold(
      // The only extra on the page — the Publish pill rides in the social
      // icons row and appears only while there are unsaved changes, so the
      // clean editor is a pixel replica of Home.
      body: ProfileView(
        content: content,
        onCoverTap: _pickCover,
        onAvatarTap: _pickAvatar,
        onNameTap: () => setState(() => _editingName = true),
        onBioTap: () => setState(() => _editingBio = true),
        onNameEditDone: () => setState(() => _editingName = false),
        onBioEditDone: () => setState(() => _editingBio = false),
        nameController: _nameController,
        bioController: _bioController,
        editingName: _editingName,
        editingBio: _editingBio,
        coverBytes: _coverBytes,
        avatarBytes: _avatarBytes,
        onSocialTap: _editSocialLink,
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

/// Popup card for setting one social handle's link. Shows the (non-editable)
/// icon followed by the link field; Save pops the trimmed link back to the
/// editor, which marks the page dirty so the Publish pill appears.
class _SocialLinkDialog extends StatefulWidget {
  const _SocialLinkDialog({
    required this.icon,
    required this.label,
    required this.initialLink,
  });

  final IconData icon;
  final String label;
  final String initialLink;

  @override
  State<_SocialLinkDialog> createState() => _SocialLinkDialogState();
}

class _SocialLinkDialogState extends State<_SocialLinkDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialLink,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      title: Row(
        children: [
          Icon(widget.icon, size: 22, color: Colors.white70),
          const SizedBox(width: 10),
          Text(
            widget.label,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: TextField(
          controller: _controller,
          autofocus: true,
          cursorColor: Colors.white70,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: Colors.white10,
            hintText: 'https://…',
            hintStyle: const TextStyle(color: Colors.white24),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white24),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.blue),
            ),
          ),
          onSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text(
            'Save',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
