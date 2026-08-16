import 'package:flutter/foundation.dart';

/// In-memory signed-in state for routing, fed by `FirebaseAuth`'s stream in
/// `main()`. Kept out of the widget tree so tests run without a Firebase app.
class AuthState {
  AuthState._();

  static final AuthState instance = AuthState._();

  /// True while an admin is signed in.
  final ValueNotifier<bool> signedIn = ValueNotifier<bool>(false);

  bool get isSignedIn => signedIn.value;
}
