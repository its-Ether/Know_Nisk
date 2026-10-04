/// Web implementation of [favicon.dart] — keeps the favicon and
/// apple-touch-icon links pointed at the site's fixed identity icon, the
/// bundled Nisk-Fav image.
library;

import 'package:web/web.dart' as web;

void syncFavicon(String? avatarUrl) {
  // The site icon no longer follows the profile picture — the Nisk-Fav
  // identity serves everywhere (tab, home screen, manifest). The built
  // app serves bundled assets at assets/<logical path>. The parameter
  // stays in the signature so the call sites don't change.
  const href = 'assets/assets/Nisk-Fav.png';
  for (final rel in ['icon', 'apple-touch-icon']) {
    final link = web.document.querySelector('link[rel="$rel"]');
    link?.setAttribute('href', href);
  }
}
