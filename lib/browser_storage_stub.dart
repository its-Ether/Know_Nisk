/// Non-web fallback for [browser_storage.dart] — no browser localStorage in
/// the test VM, so reads miss and writes are ignored.
library;

String? localStorageGet(String key) => null;

void localStorageSet(String key, String value) {}
