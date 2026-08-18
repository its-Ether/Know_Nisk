/// Web implementation of [favicon.dart] — repoints the favicon <link> at the
/// published avatar URL (or the bundled placeholder until one is published).
library;

import 'package:web/web.dart' as web;

void syncFavicon(String? avatarUrl) {
  // The built app serves bundled assets at assets/<logical path>; this is
  // the same image the profile shows while no picture is published.
  final href = (avatarUrl != null && avatarUrl.isNotEmpty)
      ? avatarUrl
      : 'assets/assets/avatar_placeholder.png';
  for (final rel in ['icon', 'apple-touch-icon']) {
    final link = web.document.querySelector('link[rel="$rel"]');
    link?.setAttribute('href', href);
  }
}
