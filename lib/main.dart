import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:go_router/go_router.dart';

import 'auth_state.dart';
import 'firebase_options.dart';
import 'pages/admin_editor_page.dart';
import 'pages/admin_page.dart';
import 'pages/home_page.dart';
import 'pages/post_detail_page.dart';
import 'posts_service.dart';
import 'site_content_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Use clean paths (/admin) instead of the default hash URLs (#/admin).
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Seed auth state before the router builds, so a direct load of
  // /admin-editor keeps signed-in users in and redirects everyone else.
  AuthState.instance.signedIn.value = FirebaseAuth.instance.currentUser != null;
  FirebaseAuth.instance.authStateChanges().listen(
    (user) => AuthState.instance.signedIn.value = user != null,
  );
  // Feed the Home page + editor from Firestore; publishing in the editor
  // then shows up live (errors keep the last known content).
  SiteContentService.instance.watch().listen(
    (content) => SiteContentState.instance.content.value = content,
    onError: (Object _) {},
  );
  // Same for the post feed — posts appear on Home the moment they're
  // published from the editor.
  PostsService.instance.watchPosts().listen(
    (posts) => PostsState.instance.posts.value = posts,
    onError: (Object _) {},
  );
  runApp(const KnowN1SKApp());
}

/// Know N1SK — N1SK's personal site.
class KnowN1SKApp extends StatelessWidget {
  const KnowN1SKApp({super.key});

  /// Route table: `/` is the public profile, `/admin` signs admins in,
  /// `/admin-editor` is the editor — signed-in access only.
  static final GoRouter _router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: '/admin',
        builder: (context, state) => const AdminPage(),
      ),
      GoRoute(
        path: '/admin-editor',
        builder: (context, state) => const AdminEditorPage(),
      ),
      // The shareable full-post page — what a shared post link opens.
      GoRoute(
        path: '/post/:id',
        builder: (context, state) =>
            PostDetailPage(postId: state.pathParameters['id']!),
      ),
    ],
    redirect: (context, state) {
      // The editor is for signed-in admins only; everyone else goes Home.
      if (!AuthState.instance.isSignedIn &&
          state.matchedLocation == '/admin-editor') {
        return '/';
      }
      return null;
    },
  );

  /// Test hook — lets the widget tests reset navigation back to Home
  /// between runs (the router is a process-wide singleton).
  @visibleForTesting
  static GoRouter get router => _router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Know N1SK',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF000000),
      ),
      routerConfig: _router,
    );
  }
}
