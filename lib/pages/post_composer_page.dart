import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../image_utils.dart';
import '../posts_service.dart';

/// The full-screen post composer opened by the pen button on the admin
/// editor. Creates a new post or (when [existing] is given) edits one in
/// place: text, up to 4 images, one video, one link, and the folder the
/// post is filed under — chosen from the existing folders or created on the
/// spot. Publishing to a brand-new folder creates that tab on the Home page.
class PostComposerPage extends StatefulWidget {
  const PostComposerPage({super.key, this.existing});

  /// The post being edited; null creates a new one.
  final Post? existing;

  @override
  State<PostComposerPage> createState() => _PostComposerPageState();
}

class _PostComposerPageState extends State<PostComposerPage> {
  static const String _createFolderValue = '__create_folder__';

  late final TextEditingController _textController = TextEditingController(
    text: widget.existing?.text ?? '',
  );

  /// Newly picked images (already downscaled) plus their extension.
  final List<({Uint8List bytes, String ext})> _newImages = [];

  /// Image URLs already published on the post being edited.
  late final List<String> _existingImages = [
    ...?widget.existing?.images,
  ];

  Uint8List? _videoBytes;
  String? _videoName;
  String _existingVideoUrl = '';
  String _linkUrl = '';
  late String _folder = widget.existing?.folder ?? '';
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _existingVideoUrl = widget.existing?.videoUrl ?? '';
    _linkUrl = widget.existing?.linkUrl ?? '';
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<String> get _folders => PostsState.instance.folders;

  bool get _canPublish =>
      !_publishing &&
      _folder.isNotEmpty &&
      (_textController.text.trim().isNotEmpty ||
          _existingImages.isNotEmpty ||
          _newImages.isNotEmpty ||
          _videoBytes != null ||
          _existingVideoUrl.isNotEmpty ||
          _linkUrl.isNotEmpty);

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

  Future<void> _onFolderChanged(String? value) async {
    if (value == null) return;
    if (value == _createFolderValue) {
      final name = await showDialog<String>(
        context: context,
        builder: (_) => _FolderNameDialog(existing: _folders),
      );
      if (name == null || !mounted) return;
      setState(() => _folder = name);
    } else {
      setState(() => _folder = value);
    }
  }

  Future<void> _addImage() async {
    final total = _existingImages.length + _newImages.length;
    if (total >= 4) {
      _snack('Up to 4 images per post');
      return;
    }
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final prepared = prepareImageForUpload(bytes, maxWidth: 1200);
    if (!mounted) return;
    setState(() => _newImages.add((bytes: prepared.bytes, ext: prepared.ext)));
  }

  Future<void> _addVideo() async {
    if (_videoBytes != null || _existingVideoUrl.isNotEmpty) {
      _snack('One video per post');
      return;
    }
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || !mounted) return;
    setState(() {
      _videoBytes = file.bytes;
      _videoName = file.name;
    });
  }

  Future<void> _addLink() async {
    final url = await showDialog<String>(
      context: context,
      builder: (_) => _LinkDialog(initial: _linkUrl),
    );
    if (url == null || !mounted) return;
    setState(() => _linkUrl = url);
  }

  String _videoContentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.m4v')) return 'video/x-m4v';
    return 'video/mp4';
  }

  Future<void> _publish() async {
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final service = PostsService.instance;

      final uploadedImages = <String>[];
      for (final image in _newImages) {
        uploadedImages.add(
          await service.uploadFile(
            bytes: image.bytes,
            name:
                'img_${DateTime.now().millisecondsSinceEpoch}_${uploadedImages.length}.${image.ext}',
            contentType: image.ext == 'png' ? 'image/png' : 'image/jpeg',
          ),
        );
      }

      var videoUrl = _existingVideoUrl;
      if (_videoBytes != null) {
        videoUrl = await service.uploadFile(
          bytes: _videoBytes!,
          name:
              'video_${DateTime.now().millisecondsSinceEpoch}.${_videoName?.split('.').last.toLowerCase() ?? 'mp4'}',
          contentType: _videoContentType(_videoName ?? ''),
        );
      }

      final images = [..._existingImages, ...uploadedImages];
      final text = _textController.text.trim();
      final linkUrl = _linkUrl.trim();

      final existing = widget.existing;
      String? postId;
      if (existing == null) {
        postId = await service.createPost(
          folder: _folder,
          text: text,
          images: images,
          videoUrl: videoUrl,
          linkUrl: linkUrl,
        );
      } else {
        postId = existing.id;
        await service.updatePost(
          Post(
            id: existing.id,
            folder: _folder,
            text: text,
            images: images,
            videoUrl: videoUrl,
            linkUrl: linkUrl,
            views: existing.views,
            createdAt: existing.createdAt,
          ),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(existing == null ? 'Post published' : 'Post saved'),
          backgroundColor: const Color(0xFF111111),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.blue,
            onPressed: () => router.go('/post/$postId'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _publishing = false);
      _snack('Publish failed: $e', error: true);
    }
  }

  Widget _thumbnail({
    required Widget image,
    required VoidCallback onRemove,
  }) {
    return SizedBox(
      width: 84,
      height: 84,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: image,
          ),
          Positioned(
            top: 2,
            right: 2,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(3),
                child: const Icon(
                  Icons.close,
                  size: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attachmentChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 16, color: Colors.white54),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    final hasVideo = _videoBytes != null || _existingVideoUrl.isNotEmpty;
    if (_existingImages.isEmpty &&
        _newImages.isEmpty &&
        !hasVideo &&
        _linkUrl.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final url in _existingImages)
            _thumbnail(
              image: Image.network(url, fit: BoxFit.cover),
              onRemove: () => setState(() => _existingImages.remove(url)),
            ),
          for (var i = 0; i < _newImages.length; i++)
            _thumbnail(
              image: Image.memory(_newImages[i].bytes, fit: BoxFit.cover),
              onRemove: () => setState(() => _newImages.removeAt(i)),
            ),
          if (hasVideo)
            _attachmentChip(
              icon: Icons.videocam_outlined,
              label: _videoName ?? 'Video',
              onRemove: () => setState(() {
                _videoBytes = null;
                _videoName = null;
                _existingVideoUrl = '';
              }),
            ),
          if (_linkUrl.isNotEmpty)
            _attachmentChip(
              icon: Icons.link,
              label: _linkUrl,
              onRemove: () => setState(() => _linkUrl = ''),
            ),
        ],
      ),
    );
  }

  Widget _addButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16, color: Colors.white70),
      label: Text(label, style: const TextStyle(color: Colors.white70)),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Colors.white24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        foregroundColor: Colors.white70,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existing;
    // The folder dropdown lists every published folder plus the current
    // choice (a folder created moments ago isn't in the list until its post
    // is published), and the "create" entry at the bottom.
    final folderItems = <DropdownMenuItem<String>>[
      if (_folder.isNotEmpty && !_folders.contains(_folder))
        DropdownMenuItem(value: _folder, child: Text(_folder)),
      for (final folder in _folders)
        DropdownMenuItem(value: folder, child: Text(folder)),
      const DropdownMenuItem(
        value: _createFolderValue,
        child: Text(
          'Create new folder…',
          style: TextStyle(color: Colors.white70),
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    existing == null ? 'New post' : 'Edit post',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _folder.isEmpty ? null : _folder,
                  hint: const Text(
                    'Select folder…',
                    style: TextStyle(color: Colors.white54),
                  ),
                  dropdownColor: const Color(0xFF0D0D0D),
                  iconEnabledColor: Colors.white70,
                  style: const TextStyle(color: Colors.white),
                  items: folderItems,
                  onChanged: _onFolderChanged,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _textController,
                  minLines: 6,
                  maxLines: null,
                  cursorColor: Colors.white70,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    height: 1.4,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Write a post…',
                    hintStyle: const TextStyle(color: Colors.white24),
                    filled: true,
                    fillColor: Colors.white10,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.white24),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              _buildAttachments(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _addButton(
                    label: 'Image',
                    icon: Icons.image_outlined,
                    onPressed: _addImage,
                  ),
                  const SizedBox(width: 8),
                  _addButton(
                    label: 'Video',
                    icon: Icons.videocam_outlined,
                    onPressed: _addVideo,
                  ),
                  const SizedBox(width: 8),
                  _addButton(
                    label: 'Link',
                    icon: Icons.link,
                    onPressed: _addLink,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _canPublish ? _publish : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: Colors.white10,
                  disabledForegroundColor: Colors.white38,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                ),
                child: _publishing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : Text(
                        existing == null ? 'Publish' : 'Save',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small dialog that names a brand-new folder. The name must be non-empty
/// and unique (case-insensitive) against the folders that already exist.
class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({required this.existing});

  final List<String> existing;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the folder a name');
      return;
    }
    final lower = name.toLowerCase();
    if (widget.existing.any((f) => f.toLowerCase() == lower)) {
      setState(() => _error = 'That folder already exists');
      return;
    }
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      title: const Text(
        'New folder',
        style: TextStyle(color: Colors.white, fontSize: 17),
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
            hintText: 'Folder name',
            hintStyle: const TextStyle(color: Colors.white24),
            errorText: _error,
            errorStyle: const TextStyle(color: Colors.redAccent),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// Small dialog that types the link attachment for the post.
class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.initial});

  final String initial;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial,
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
      title: const Text(
        'Add a link',
        style: TextStyle(color: Colors.white, fontSize: 17),
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
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
