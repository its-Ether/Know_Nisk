import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'posts_service.dart';

/// Shares a post via the native Web Share API where available; otherwise
/// copies the post's canonical link to the clipboard and confirms it.
/// Failures are swallowed so sharing can never break the page — in widget
/// tests there is no share backend at all, so the tap is a safe no-op.
Future<void> sharePost(BuildContext context, Post post) async {
  final url = Uri.base.replace(path: '/post/${post.id}').toString();
  try {
    await SharePlus.instance.share(
      ShareParams(text: '${post.text}\n\n$url'),
    );
    return;
  } catch (_) {}
  try {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Link copied'),
          backgroundColor: Color(0xFF111111),
        ),
      );
    }
  } catch (_) {}
}
