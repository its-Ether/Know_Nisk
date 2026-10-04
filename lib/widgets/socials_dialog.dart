import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../site_content_service.dart';

/// The socials dialog — one box, two personalities.
///
/// * **Viewer mode** (public Home): lists every social slot as
///   `icon + title + link`; tapping a live slot opens its link in a new
///   tab. Slots without a link are greyed-out (visible but asleep).
/// * **Editor mode** (admin editor): the same box, but every slot is
///   editable — a tappable icon (pick a custom image), a title field, a
///   link field — plus add/remove, and one Done button. The result goes
///   back to the editor page as *pending* changes for the Publish pill.
///
/// The dialog has no heading on purpose — just the slots, clean and dark.
class SocialsDialog extends StatelessWidget {
  /// Viewer mode: read-only slots for the public Home page.
  const SocialsDialog.viewer({super.key, required this.socials})
      : editable = false;

  /// Editor mode: every slot editable, result popped on Done.
  const SocialsDialog.editor({super.key, required this.socials})
      : editable = true;

  /// The slots to show (viewer) or edit (editor).
  final List<SocialLink> socials;

  /// Whether the slots are editable (admin editor mode).
  final bool editable;

  @override
  Widget build(BuildContext context) {
    if (!editable) {
      return _viewerDialog(context);
    }
    return _EditorSocialsDialog(initial: socials);
  }

  Widget _viewerDialog(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < socials.length; i++) ...[
              if (i > 0) const Divider(height: 1, color: Colors.white12),
              _ViewerSlotRow(social: socials[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// One row in the viewer dialog: the slot's icon, its title and its link.
/// A slot with a link opens it in a new tab when tapped; a slot without
/// one is greyed-out and inert (visible, but asleep).
class _ViewerSlotRow extends StatelessWidget {
  const _ViewerSlotRow({required this.social});

  final SocialLink social;

  Future<void> _openLink() async {
    try {
      var target = social.link.trim();
      if (!target.startsWith('http://') && !target.startsWith('https://')) {
        target = 'https://$target';
      }
      await launchUrl(Uri.parse(target), webOnlyWindowName: '_blank');
    } catch (_) {}
  }

  /// The link shown as friendly text — the scheme noise stripped off and
  /// long URLs trimmed with an ellipsis.
  String get _linkLabel {
    var label = social.link.trim();
    label = label.replaceFirst(RegExp(r'^https?://'), '');
    label = label.replaceFirst(RegExp(r'^www\.'), '');
    return label.length > 42 ? '${label.substring(0, 42)}…' : label;
  }

  @override
  Widget build(BuildContext context) {
    final live = social.isLive;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SocialIconView(
            social: social,
            size: 22,
            greyed: !live,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  social.title.isEmpty ? 'Social' : social.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: live ? Colors.white : Colors.white24,
                  ),
                ),
                if (live)
                  Text(
                    _linkLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!live) return row;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _openLink,
        child: row,
      ),
    );
  }
}

/// A social slot's icon: the custom uploaded image when there is one, the
/// classic brand icon when the title names a known brand, and a neutral
/// link icon otherwise. Shared by the dialog rows and the profile header.
class SocialIconView extends StatelessWidget {
  const SocialIconView({
    super.key,
    required this.social,
    required this.size,
    this.greyed = false,
    this.bytes,
  });

  final SocialLink social;

  /// Icon size in logical pixels (22 in the header and dialog rows).
  final double size;

  /// Greyed-out rendering for empty slots (visible but asleep).
  final bool greyed;

  /// Newly picked custom icon bytes (editor preview) — shown instead of
  /// the network image while the change is still pending.
  final Uint8List? bytes;

  static FaIconData? _brandIcon(String title) {
    final t = title.trim().toLowerCase();
    if (t.contains('facebook')) return FontAwesomeIcons.facebookF;
    if (t == 'x' || t.contains('twitter') || t.contains('x.com')) {
      return FontAwesomeIcons.xTwitter;
    }
    if (t.contains('github')) return FontAwesomeIcons.github;
    if (t.contains('instagram')) return FontAwesomeIcons.instagram;
    if (t.contains('linkedin')) return FontAwesomeIcons.linkedinIn;
    if (t.contains('youtube')) return FontAwesomeIcons.youtube;
    if (t.contains('discord')) return FontAwesomeIcons.discord;
    if (t.contains('telegram')) return FontAwesomeIcons.telegram;
    if (t.contains('reddit')) return FontAwesomeIcons.redditAlien;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hasCustom = bytes != null || social.iconUrl.isNotEmpty;
    final color = greyed ? Colors.white24 : Colors.white70;
    if (hasCustom) {
      final image = bytes != null
          ? Image.memory(
              bytes!,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(Icons.link, size: size, color: color),
            )
          : Image.network(
              social.iconUrl,
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.link, size: size, color: color),
            );
      return Opacity(opacity: greyed ? 0.4 : 1, child: image);
    }
    final brand = _brandIcon(social.title);
    if (brand != null) {
      return FaIcon(brand, size: size, color: color);
    }
    return Icon(Icons.link, size: size, color: color);
  }
}

/// One editable slot handed back by the editor dialog: the slot's new
/// [SocialLink] plus the freshly picked custom icon bytes (null = keep the
/// current icon image, if any).
class SocialEdit {
  const SocialEdit({required this.link, this.newIconBytes});

  final SocialLink link;
  final Uint8List? newIconBytes;
}

/// The editor flavor: every slot editable at once, add/remove slots, one
/// Done button. Pops with the full [SocialEdit] list (null on cancel).
class _EditorSocialsDialog extends StatefulWidget {
  const _EditorSocialsDialog({required this.initial});

  final List<SocialLink> initial;

  @override
  State<_EditorSocialsDialog> createState() => _EditorSocialsDialogState();
}

class _EditorSocialsDialogState extends State<_EditorSocialsDialog> {
  late final List<TextEditingController> _titleControllers = [
    for (final social in widget.initial)
      TextEditingController(text: social.title),
  ];
  late final List<TextEditingController> _linkControllers = [
    for (final social in widget.initial)
      TextEditingController(text: social.link),
  ];
  late final List<String?> _iconUrls = [
    for (final social in widget.initial) social.iconUrl,
  ];
  final List<Uint8List?> _iconBytes = [];

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _titleControllers.length; i++) {
      _iconBytes.add(null);
    }
  }

  @override
  void dispose() {
    for (final controller in _titleControllers) {
      controller.dispose();
    }
    for (final controller in _linkControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickIcon(int index) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _iconBytes[index] = bytes);
  }

  void _addSlot() {
    setState(() {
      _titleControllers.add(TextEditingController());
      _linkControllers.add(TextEditingController());
      _iconUrls.add(null);
      _iconBytes.add(null);
    });
  }

  void _removeSlot(int index) {
    setState(() {
      _titleControllers.removeAt(index).dispose();
      _linkControllers.removeAt(index).dispose();
      _iconUrls.removeAt(index);
      _iconBytes.removeAt(index);
    });
  }

  void _done() {
    final edits = <SocialEdit>[];
    for (var i = 0; i < _titleControllers.length; i++) {
      edits.add(
        SocialEdit(
          link: SocialLink(
            title: _titleControllers[i].text.trim(),
            link: _linkControllers[i].text.trim(),
            iconUrl: _iconBytes[i] != null ? '' : (_iconUrls[i] ?? ''),
          ),
          newIconBytes: _iconBytes[i],
        ),
      );
    }
    Navigator.pop(context, edits);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF0D0D0D),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12),
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < _titleControllers.length; i++)
                _EditorSlotRow(
                  index: i,
                  iconUrl: _iconUrls[i] ?? '',
                  iconBytes: _iconBytes[i],
                  titleController: _titleControllers[i],
                  linkController: _linkControllers[i],
                  onIconTap: () => _pickIcon(i),
                  onRemove: () => _removeSlot(i),
                ),
              TextButton.icon(
                onPressed: _addSlot,
                icon: const Icon(Icons.add, size: 18, color: Colors.white54),
                label: const Text(
                  'Add social',
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(
          onPressed: _done,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
          ),
          child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

/// One editable slot: a tappable icon (pick a custom image), the title and
/// link fields stacked beside it, and a small remove button on the right.
class _EditorSlotRow extends StatelessWidget {
  const _EditorSlotRow({
    required this.index,
    required this.iconUrl,
    required this.iconBytes,
    required this.titleController,
    required this.linkController,
    required this.onIconTap,
    required this.onRemove,
  });

  final int index;
  final String iconUrl;
  final Uint8List? iconBytes;
  final TextEditingController titleController;
  final TextEditingController linkController;
  final VoidCallback onIconTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The tappable icon — a small square so any custom image shape
          // fits, with the current icon (bytes > network > brand fallback).
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: onIconTap,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Center(
                    child: SocialIconView(
                      social: SocialLink(
                        title: titleController.text,
                        link: '',
                        iconUrl: iconUrl,
                      ),
                      bytes: iconBytes,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              children: [
                _field(
                  controller: titleController,
                  hint: 'Title (e.g. GitHub)',
                ),
                const SizedBox(height: 8),
                _field(
                  controller: linkController,
                  hint: 'https://…',
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 16, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _field({required TextEditingController controller, required String hint}) {
    return TextField(
      controller: controller,
      cursorColor: Colors.white70,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.white10,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.blue),
        ),
      ),
    );
  }
}
