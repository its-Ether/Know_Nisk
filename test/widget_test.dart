import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:go_router/go_router.dart';

import 'package:know/auth_state.dart';
import 'package:know/main.dart';
import 'package:know/pages/admin_editor_page.dart';
import 'package:know/pages/admin_page.dart';
import 'package:know/pages/home_page.dart';
import 'package:know/pages/post_detail_page.dart';
import 'package:know/posts_service.dart';
import 'package:know/site_content_service.dart';

/// v11 FontAwesome icons render in `FaIcon` widgets, and `FaIcon.icon`
/// exposes the wrapped `IconData` — match on that, not byIcon.
Finder findFaIcon(FaIconData icon) => find.byWidgetPredicate(
      (widget) => widget is FaIcon && widget.icon == icon.data,
    );

void main() {
  setUp(() {
    // Tests can't fetch fonts over HTTP; resolve Google Fonts to fallbacks.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Serve a real 1x1 PNG for every network image: the test binding's
    // default HTTP client answers with 400, and an image that outlives its
    // widget (the feed images under the fullscreen gallery route) reports
    // its late load error as a test exception even with an errorBuilder.
    // (Set before the first network image load, so NetworkImage's shared
    // HTTP client is built from these overrides.)
    HttpOverrides.global = _FakeImageHttpOverrides();
    // Start each test logged out (AuthState is a shared singleton).
    AuthState.instance.signedIn.value = false;
    // Start each test without published site content or posts.
    SiteContentState.instance.content.value = null;
    SiteContentState.instance.siteViews.value = 0;
    PostsState.instance.posts.value = const [];
    // The app's GoRouter is a process-wide singleton — a test that
    // navigated (e.g. to /post/:id) would otherwise leak into the next one
    // and re-render that page (and its loading spinner) forever.
    KnowN1SKApp.router.go('/');
  });

  testWidgets('Know N1SK renders the Home page', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('N1SK'), findsOneWidget);
    expect(find.text('Nisk.Niship'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    // With no posts yet, the only tab is the catch-all Updates.
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('No posts yet'), findsOneWidget);
  });

  testWidgets('bio sits directly under the username — no phantom gap', (
    tester,
  ) async {
    await tester.pumpWidget(const KnowN1SKApp());

    final usernameBottom = tester.getBottomLeft(find.text('Nisk.Niship')).dy;
    final bioTop =
        tester.getTopLeft(find.textContaining('Aspiring developer')).dy;

    // The profile block adds 12px top padding; the old Transform-based
    // layout left ~80px of phantom space. Anything well under 40px proves
    // the gap is gone.
    expect(bioTop - usernameBottom, lessThan(40));
  });

  testWidgets('avatar overlaps the cover bottom edge', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    final coverBottom = tester.getBottomLeft(find.byType(Image)).dy;
    final avatarTop = tester.getTopLeft(find.byType(CircleAvatar)).dy;
    expect(avatarTop, lessThan(coverBottom));
  });

  testWidgets('eye icon sits directly before the views count', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    final eyeCenter = tester.getCenter(find.byIcon(Icons.visibility));
    final viewsCenter = tester.getCenter(find.text('0'));
    expect(viewsCenter.dx, greaterThan(eyeCenter.dx));
    expect(viewsCenter.dx - eyeCenter.dx, lessThan(80));
  });

  testWidgets('folder tabs filter the post feed', (tester) async {
    PostsState.instance.posts.value = const [
      Post(id: 'p1', folder: 'Music', text: 'Music post', views: 0),
      Post(id: 'p2', folder: 'Tech', text: 'Tech post', views: 0),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // Updates first, then one tab per folder. On the mixed Updates feed the
    // cards also show their folder chip, so each folder name appears twice
    // (the tab plus the chip on its post).
    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Music'), findsNWidgets(2));
    expect(find.text('Tech'), findsNWidgets(2));
    expect(find.text('Music post'), findsOneWidget);
    expect(find.text('Tech post'), findsOneWidget);

    // A folder tab shows only its own posts — and the chips disappear,
    // because the folder is obvious from the tab itself.
    await tester.tap(find.text('Music').first);
    await tester.pumpAndSettle();
    expect(find.text('Music post'), findsOneWidget);
    expect(find.text('Tech post'), findsNothing);
    expect(find.text('Music'), findsOneWidget);

    // Back to Updates — everything again.
    await tester.tap(find.text('Updates'));
    await tester.pumpAndSettle();
    expect(find.text('Tech post'), findsOneWidget);
  });

  testWidgets('a long post is clamped to a few lines on the feed', (
    tester,
  ) async {
    final longText = List.filled(80, 'sentence').join(' ');
    PostsState.instance.posts.value = [
      Post(id: 'p1', folder: 'Music', text: longText, views: 0),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    final cardText = tester.widget<Text>(find.text(longText));
    expect(cardText.maxLines, 4);
    expect(cardText.overflow, TextOverflow.ellipsis);
  });

  testWidgets('tapping a post opens the full post popup', (tester) async {
    PostsState.instance.posts.value = const [
      Post(id: 'p1', folder: 'Music', text: 'A short post.', views: 3),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // The post sits below the 600px test viewport — bring it into view first.
    await tester.ensureVisible(find.text('A short post.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A short post.'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('/post/:id opens the shareable full post page', (tester) async {
    PostsState.instance.posts.value = const [
      Post(id: 'p1', folder: 'Music', text: 'Deep link post', views: 2),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/post/p1');
    await tester.pumpAndSettle();

    expect(find.byType(PostDetailPage), findsOneWidget);
    expect(find.text('Deep link post'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('share tap is a safe no-op in widget tests', (tester) async {
    PostsState.instance.posts.value = const [
      Post(id: 'p1', folder: 'Music', text: 'Shared post.', views: 1),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // No share backend exists in tests — the tap must simply not blow up.
    await tester.ensureVisible(find.byIcon(Icons.share_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.share_outlined).first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long bio clamps to 5 lines and expands on tap', (
    tester,
  ) async {
    final longBio = List.filled(100, 'word').join(' ');
    SiteContentState.instance.content.value = SiteContent(
      coverUrl: '',
      avatarUrl: '',
      name: 'nisk',
      bio: longBio,
    );
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    Text bioText() => tester.widget<Text>(find.text(longBio));
    // Longer than 5 lines: clamped with an ellipsis…
    expect(bioText().maxLines, 5);
    // …tap expands to the full text…
    await tester.tap(find.text(longBio));
    await tester.pumpAndSettle();
    expect(bioText().maxLines, isNull);
    // …and tapping again collapses it.
    await tester.tap(find.text(longBio));
    await tester.pumpAndSettle();
    expect(bioText().maxLines, 5);
  });

  testWidgets('screen background is pure black', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.theme?.scaffoldBackgroundColor, const Color(0xFF000000));
  });

  testWidgets('/admin routes to the admin sign-in form', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    // Navigate to the admin route.
    tester.state<NavigatorState>(find.byType(Navigator)).context.go('/admin');
    await tester.pumpAndSettle();

    expect(find.byType(AdminPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    // Sign-in form: email + password fields and a sign-in button.
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Sign in'), findsOneWidget);
    // No sign-up affordance on the page.
    expect(find.text('Create account'), findsNothing);
  });

  testWidgets('/admin-editor redirects to Home when not signed in', (
    tester,
  ) async {
    await tester.pumpWidget(const KnowN1SKApp());

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // Logged-out visitor is bounced to the Home screen.
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(AdminEditorPage), findsNothing);
  });

  testWidgets('/admin-editor is a Home replica with tap-to-edit', (
    tester,
  ) async {
    AuthState.instance.signedIn.value = true;
    await tester.pumpWidget(const KnowN1SKApp());

    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // Signed-in admin lands on the editor: the exact Home structure...
    expect(find.byType(AdminEditorPage), findsOneWidget);
    expect(find.byType(HomePage), findsNothing);
    expect(find.text('N1SK'), findsOneWidget);
    expect(find.text('Nisk.Niship'), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    // ...with no form chrome and no Publish button until something changes.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Publish'), findsNothing);

    // Tapping the name makes it editable; typing reveals the Publish pill.
    await tester.tap(find.text('N1SK'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    // Tapping alone must not mark the page dirty — only an actual text edit.
    expect(find.text('Publish'), findsNothing);

    await tester.enterText(find.byType(TextField), 'N1SK Diag');
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsOneWidget);
    // The Publish pill rides in the social icons row, right of the GitHub
    // icon — not floating on the screen.
    final publishCenter = tester.getCenter(find.text('Publish'));
    final githubCenter = tester.getCenter(findFaIcon(FontAwesomeIcons.github));
    expect((publishCenter.dy - githubCenter.dy).abs(), lessThan(20));
    expect(publishCenter.dx, greaterThan(githubCenter.dx));
  });

  testWidgets('a bio published empty still shows a tappable bio in the editor', (
    tester,
  ) async {
    // Regression: the site was published without a bio, leaving an empty
    // string in Firestore. The bio must fall back to the placeholder text so
    // there is something visible to tap and edit.
    AuthState.instance.signedIn.value = true;
    SiteContentState.instance.content.value = const SiteContent(
      coverUrl: '',
      avatarUrl: '',
      name: 'nisk',
      bio: '',
    );
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // The placeholder bio renders instead of nothing…
    final bioFinder = find.textContaining('Aspiring developer');
    expect(bioFinder, findsOneWidget);

    // …and tapping it opens the bio field to type a real one.
    await tester.tap(bioFinder);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Write a bio…'), findsOneWidget);
  });

  testWidgets('socials area tap opens the editor dialog; Done reveals Publish',
      (tester) async {
    AuthState.instance.signedIn.value = true;
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // Tapping anywhere on the socials area opens ONE dialog with ALL
    // THREE slots editable at once: each slot is a title field + a link
    // field (6 fields), plus add/remove — no per-icon popups anymore.
    await tester.tap(findFaIcon(FontAwesomeIcons.github));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(6));
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Add social'), findsOneWidget);
    expect(find.text('Publish'), findsNothing);

    // Filling a link and tapping Done closes the dialog and marks the
    // page dirty — the Publish pill appears. Slot order is Facebook, X,
    // GitHub, each slot a title field followed by its link field — the
    // GitHub link is field index 5.
    await tester.enterText(find.byType(TextField).at(5), 'github.com/nisk');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Done'), findsNothing);
    expect(find.text('Publish'), findsOneWidget);
  });

  testWidgets('home socials tap opens the viewer dialog, page stays intact', (
    tester,
  ) async {
    SiteContentState.instance.content.value = const SiteContent(
      coverUrl: '',
      avatarUrl: '',
      name: 'nisk',
      bio: 'bio',
      socials: [SocialLink(title: 'GitHub', link: 'github.com/nisk')],
    );
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // Tapping the icons area opens the socials dialog — the slot's icon +
    // title + link — while the page stays intact behind it.
    await tester.tap(findFaIcon(FontAwesomeIcons.github));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('nisk'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.text('github.com/nisk'), findsOneWidget);
  });

  testWidgets('social icons sit on the far right, level with the name', (
    tester,
  ) async {
    await tester.pumpWidget(const KnowN1SKApp());

    // The icons stay on the right side of the screen — right of the views
    // counter and in the right half of the 800px test surface.
    final githubCenter = tester.getCenter(findFaIcon(FontAwesomeIcons.github));
    final viewsCenter = tester.getCenter(find.text('0'));
    expect(githubCenter.dx, greaterThan(viewsCenter.dx));
    expect(githubCenter.dx, greaterThan(400));

    // Level with the views counter — both sit at the profile name, not
    // mid-column and not hugging the bio below.
    expect((githubCenter.dy - viewsCenter.dy).abs(), lessThan(10));
  });

  testWidgets('Home holds up on a narrow phone-width screen', (tester) async {
    // 360x800 @1x — a typical phone. The header stays ONE line: the social
    // icons remain level with the views counter (beside the profile name),
    // never dropping to their own line.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Everything still renders: profile block + icons + counter.
    expect(find.text('N1SK'), findsOneWidget);
    expect(find.text('Nisk.Niship'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(findFaIcon(FontAwesomeIcons.github), findsOneWidget);
    expect(find.text('Updates'), findsOneWidget);
    // Regression: the icons stay on the SAME line as the views counter on
    // mobile — no vertical shift down from the bigger-screen position.
    final githubCenter = tester.getCenter(findFaIcon(FontAwesomeIcons.github));
    final counterCenter = tester.getCenter(find.text('0'));
    expect((githubCenter.dy - counterCenter.dy).abs(), lessThan(10));
  });

  testWidgets('Home survives a very narrow screen (icons stack, no overflow)', (
    tester,
  ) async {
    // 320x800 @1x — the narrowest common phone. One line no longer fits, so
    // the icons fall back to their own right-aligned line — but nothing may
    // overflow or throw.
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('N1SK'), findsOneWidget);
    expect(findFaIcon(FontAwesomeIcons.github), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('the editor has a floating pen that opens the composer', (
    tester,
  ) async {
    AuthState.instance.signedIn.value = true;
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // The blue circle pen sits on the editor, bottom-right.
    final fab = find.byType(FloatingActionButton);
    expect(fab, findsOneWidget);
    expect(find.byIcon(Icons.edit), findsOneWidget);
    final fabCenter = tester.getCenter(fab);
    expect(fabCenter.dx, greaterThan(400));
    expect(fabCenter.dy, greaterThan(400));

    // Tapping it opens the full-page composer.
    await tester.tap(fab);
    await tester.pumpAndSettle();
    expect(find.text('New post'), findsOneWidget);
    expect(find.text('Write a post…'), findsOneWidget);
  });

  testWidgets('composer creates a new folder and enables Publish', (
    tester,
  ) async {
    AuthState.instance.signedIn.value = true;
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    // No folders yet — the dropdown offers "Create new folder…".
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create new folder…'));
    await tester.pumpAndSettle();
    expect(find.text('New folder'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'Music');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // The new folder is now the selected folder…
    expect(find.text('Music'), findsOneWidget);

    // …and once there is content the Publish pill is live.
    await tester.enterText(find.byType(TextField).first, 'Hello world');
    await tester.pumpAndSettle();
    expect(find.text('Publish'), findsOneWidget);
    final publish = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Publish'),
    );
    expect(publish.onPressed, isNotNull);
  });

  testWidgets('fresh posts show a New chip and a relative time', (
    tester,
  ) async {
    final now = DateTime.now();
    PostsState.instance.posts.value = [
      Post(
        id: 'p1',
        folder: 'Music',
        text: 'Fresh post',
        views: 0,
        createdAt: now.subtract(const Duration(hours: 2)),
      ),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(find.text('New'), findsOneWidget);
    expect(find.text('2h ago'), findsOneWidget);

    // An older post gets neither — and shows a day-based relative time.
    PostsState.instance.posts.value = [
      Post(
        id: 'p2',
        folder: 'Music',
        text: 'Old post',
        views: 0,
        createdAt: now.subtract(const Duration(days: 3)),
      ),
    ];
    await tester.pumpAndSettle();
    expect(find.text('New'), findsNothing);
    expect(find.text('3d ago'), findsOneWidget);
  });

  testWidgets('edited posts show a "· updated" hint next to the date', (
    tester,
  ) async {
    final now = DateTime.now();
    PostsState.instance.posts.value = [
      Post(
        id: 'p1',
        folder: 'Music',
        text: 'Edited post',
        views: 0,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now.subtract(const Duration(hours: 1)),
      ),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();
    expect(find.text('· updated'), findsOneWidget);
  });

  testWidgets('long posts show a read-time hint in the footer; short ones do not', (
    tester,
  ) async {
    final longText = List.filled(700, 'word').join(' ');
    PostsState.instance.posts.value = [
      Post(id: 'p1', folder: 'Music', text: longText, views: 0),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(find.text('~4 min read'), findsOneWidget);
    expect(find.byIcon(Icons.menu_book_outlined), findsOneWidget);

    // A one-liner is under a minute of reading — no hint at all.
    PostsState.instance.posts.value = const [
      Post(id: 'p2', folder: 'Music', text: 'Short.', views: 0),
    ];
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
  });

  testWidgets('counts compact to the 1.2K style', (tester) async {
    PostsState.instance.posts.value = const [
      Post(id: 'p1', folder: 'Music', text: 'Popular post', views: 1234),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();
    expect(find.text('1.2K views'), findsOneWidget);
  });

  testWidgets('the header views counter shows the live formatted count', (
    tester,
  ) async {
    SiteContentState.instance.siteViews.value = 2500;
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();
    expect(find.text('2.5K'), findsOneWidget);
  });

  testWidgets('tapping a post image opens the fullscreen gallery', (
    tester,
  ) async {
    PostsState.instance.posts.value = [
      Post(
        id: 'p1',
        folder: 'Music',
        text: 'Gallery post',
        views: 0,
        images: const [
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
      ),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(ClipRRect).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ClipRRect).first);
    await tester.pumpAndSettle();

    // The fullscreen viewer with the "1/2" position indicator.
    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a post cover shows only in the full post view, not the feed', (
    tester,
  ) async {
    PostsState.instance.posts.value = [
      Post(
        id: 'p1',
        folder: 'Music',
        text: 'Article post',
        views: 0,
        coverUrl: 'https://example.com/cover.jpg',
      ),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // The feed card leaves the cover out entirely (no image/video/link
    // attachments either, so no AspectRatio at all on the card).
    expect(find.byType(AspectRatio), findsNothing);

    // The full post popup is where the 16:9 banner appears.
    await tester.ensureVisible(find.text('Article post'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Article post'));
    await tester.pumpAndSettle();

    final aspect = tester.widget<AspectRatio>(find.byType(AspectRatio).first);
    expect(aspect.aspectRatio, 16 / 9);
  });

  testWidgets('bare links in post text render as blue links without breaking', (
    tester,
  ) async {
    PostsState.instance.posts.value = const [
      Post(
        id: 'p1',
        folder: 'Music',
        text: 'Check https://example.com/page now',
        views: 0,
      ),
    ];
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('https://example.com/page'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

/// A valid 1x1 transparent PNG served for every network image, so
/// [NetworkImage] decodes successfully and never surfaces a load exception.
final Uint8List _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

/// [HttpOverrides] whose client answers every request with a 1x1 PNG, so
/// [NetworkImage] loads succeed instead of hitting the test binding's
/// always-400 client.
class _FakeImageHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _FakeImageHttpClient();
}

/// The [NetworkImage] test hook only calls `getUrl`, so a client that answers
/// every request with an image is all that's needed; anything else would be
/// an unexpected code path and fails loudly.
class _FakeImageHttpClient implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _FakeImageHttpClientRequest();

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async =>
      _FakeImageHttpClientRequest();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unhandled HttpClient member: ${invocation.memberName}',
    );
  }
}

class _FakeImageHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = _NoopHttpHeaders();

  @override
  Future<HttpClientResponse> close() async => _FakeImageHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unhandled HttpClientRequest member: ${invocation.memberName}',
    );
  }
}

class _FakeImageHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  HttpHeaders get headers => _NoopHttpHeaders();

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable(<List<int>>[_transparentPng]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'Unhandled HttpClientResponse member: ${invocation.memberName}',
    );
  }
}

class _NoopHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
