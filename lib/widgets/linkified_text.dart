import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Post text with bare `http(s)://` links highlighted in the site's blue
/// accent and opened in a new tab on tap. Everything else renders exactly
/// like a plain [Text] — same style, clamping and overflow.
class LinkifiedText extends StatefulWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    this.style,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  static final RegExp _urlPattern = RegExp(r'(https?://[^\s]+)');

  @override
  State<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends State<LinkifiedText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url) async {
    try {
      await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    } catch (_) {
      // A malformed link never breaks the page.
    }
  }

  List<InlineSpan> _buildSpans() {
    // Drop recognizers from any previous build before creating new ones.
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in LinkifiedText._urlPattern.allMatches(widget.text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: widget.text.substring(start, match.start)));
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _open(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: url,
          style: const TextStyle(
            color: Colors.blue,
            decoration: TextDecoration.underline,
            decorationColor: Colors.blue,
          ),
          recognizer: recognizer,
        ),
      );
      start = match.end;
    }
    if (start < widget.text.length) {
      spans.add(TextSpan(text: widget.text.substring(start)));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: widget.style, children: _buildSpans()),
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
