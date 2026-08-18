/// Keeps the browser tab icon in step with the site's profile picture.
/// Widget tests run on the Dart VM where the browser DOM doesn't exist, so
/// the web implementation is conditionally imported and the VM falls back
/// to a no-op stub (same pattern as browser_storage.dart).
library;

import 'favicon_stub.dart' if (dart.library.html) 'favicon_web.dart' as impl;

void syncFavicon(String? avatarUrl) => impl.syncFavicon(avatarUrl);
