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
import 'package:know/site_content_service.dart';

void main() {
  setUp(() {
    // Tests can't fetch fonts over HTTP; resolve Google Fonts to fallbacks.
    GoogleFonts.config.allowRuntimeFetching = false;
    // Start each test logged out (AuthState is a shared singleton).
    AuthState.instance.signedIn.value = false;
    // Start each test without published site content.
    SiteContentState.instance.content.value = null;
  });

  testWidgets('Know N1SK renders the Home page', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.text('N1SK'), findsOneWidget);
    expect(find.text('Nisk.Niship'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.text('0 views'), findsOneWidget);
    expect(find.text('tab1'), findsOneWidget);
    expect(find.text('tab4'), findsOneWidget);
    expect(find.byIcon(Icons.article_outlined), findsOneWidget);
    expect(find.byIcon(Icons.star_outline), findsOneWidget);
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
    final viewsCenter = tester.getCenter(find.text('0 views'));
    expect(viewsCenter.dx, greaterThan(eyeCenter.dx));
    expect(viewsCenter.dx - eyeCenter.dx, lessThan(80));
  });

  testWidgets('tab icons are blue', (tester) async {
    await tester.pumpWidget(const KnowN1SKApp());

    expect(
      tester.widget<Icon>(find.byIcon(Icons.article_outlined)).color,
      Colors.blue,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.photo_outlined)).color,
      Colors.blue,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.play_circle_outline)).color,
      Colors.blue,
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.star_outline)).color,
      Colors.blue,
    );
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
    expect(find.text('tab1'), findsOneWidget);
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
    final githubCenter = tester.getCenter(find.byIcon(FontAwesomeIcons.github));
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

  testWidgets('social icon tap opens the link popup; Save reveals Publish', (
    tester,
  ) async {
    AuthState.instance.signedIn.value = true;
    await tester.pumpWidget(const KnowN1SKApp());
    tester
        .state<NavigatorState>(find.byType(Navigator))
        .context
        .go('/admin-editor');
    await tester.pumpAndSettle();

    // Tapping a social icon opens the popup: icon (not editable) + link
    // field + Save. No Publish while nothing has changed.
    await tester.tap(find.byIcon(FontAwesomeIcons.github));
    await tester.pumpAndSettle();
    expect(find.text('GitHub'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Publish'), findsNothing);

    // Filling the link and saving closes the popup and marks the page dirty.
    await tester.enterText(find.byType(TextField), 'github.com/nisk');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(find.text('Publish'), findsOneWidget);
  });

  testWidgets('home social icon tap with a link never breaks the page', (
    tester,
  ) async {
    SiteContentState.instance.content.value = const SiteContent(
      coverUrl: '',
      avatarUrl: '',
      name: 'nisk',
      bio: 'bio',
      githubUrl: 'github.com/nisk',
    );
    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    // The real redirect happens in a new browser tab; in the test the tap
    // must simply be a no-op that leaves the page intact.
    await tester.tap(find.byIcon(FontAwesomeIcons.github));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('nisk'), findsOneWidget);
  });

  testWidgets('social icons sit on the far right, level with the name', (
    tester,
  ) async {
    await tester.pumpWidget(const KnowN1SKApp());

    // The icons stay on the right side of the screen — right of the views
    // counter and in the right half of the 800px test surface.
    final githubCenter = tester.getCenter(find.byIcon(FontAwesomeIcons.github));
    final viewsCenter = tester.getCenter(find.text('0 views'));
    expect(githubCenter.dx, greaterThan(viewsCenter.dx));
    expect(githubCenter.dx, greaterThan(400));

    // Level with the views counter — both sit at the profile name, not
    // mid-column and not hugging the bio below.
    expect((githubCenter.dy - viewsCenter.dy).abs(), lessThan(10));
  });

  testWidgets('Home holds up on a narrow phone-width screen', (tester) async {
    // 360x800 @1x — the narrowest common phone. The header must wrap the
    // social icons onto their own line instead of overflowing.
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const KnowN1SKApp());
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Everything still renders: profile block + icons + counter.
    expect(find.text('N1SK'), findsOneWidget);
    expect(find.text('Nisk.Niship'), findsOneWidget);
    expect(find.text('0 views'), findsOneWidget);
    expect(find.byIcon(FontAwesomeIcons.github), findsOneWidget);
    expect(find.text('tab4'), findsOneWidget);
  });
}
