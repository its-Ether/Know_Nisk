/// Web implementation of [browser_storage.dart] backed by `window.localStorage`.
library;

import 'package:web/web.dart' as web;

String? localStorageGet(String key) => web.window.localStorage.getItem(key);

void localStorageSet(String key, String value) =>
    web.window.localStorage.setItem(key, value);
