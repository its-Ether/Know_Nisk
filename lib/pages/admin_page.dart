import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:go_router/go_router.dart';

import '../auth_state.dart';

/// Admin — the admin sign-in page of Know N1SK, served at `/admin`.
///
/// Email + password only, no sign-up: N1SK creates the credentials manually
/// in the Supabase dashboard. A successful sign-in marks [AuthState] and
/// redirects to `/admin-editor` (the editor, signed-in access only).
///
/// The page never touches the Supabase client during build — only in the
/// button handler — so the widget tests can render it without a backend.
class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      AuthState.instance.signedIn.value = true;
      context.go('/admin-editor');
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() => _error = _messageFor(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Maps auth failures to short, human-readable messages.
  String _messageFor(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
      case 'user_not_found':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'This account hasn\u2019t been confirmed yet.';
      case 'over_request_rate_limit':
        return 'Too many attempts — try again later.';
      case 'network_error':
        return 'Network error — check your connection.';
      default:
        return 'Sign-in failed: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildSignInForm());
  }

  Widget _buildSignInForm() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Admin',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  letterSpacing: 2,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Email'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                style: const TextStyle(color: Colors.white),
                decoration: _fieldDecoration('Password'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.redAccent),
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Text(
                        'Sign in',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54),
      filled: true,
      fillColor: Colors.white10,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white24),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 1.5),
      ),
    );
  }
}
