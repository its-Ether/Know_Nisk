/// A tiny localStorage facade. Widget tests run on the Dart VM where
/// `dart:html` doesn't exist, so the web implementation is conditionally
/// imported and the VM falls back to no-op stubs.
library;

import 'browser_storage_stub.dart'
    if (dart.library.html) 'browser_storage_web.dart' as impl;

String? localStorageGet(String key) => impl.localStorageGet(key);

void localStorageSet(String key, String value) => impl.localStorageSet(key, value);
