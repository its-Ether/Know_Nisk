# Know N1SK

A personal profile website for N1SK, built with Flutter and running on the web. The public page looks like an X/Twitter profile: a cover photo on top, an avatar that overlaps it, a name, a username, a bio, a "last updated" date, a view counter, and a row of tabs. Everything sits on a single pure-black background.

## What you can do

- **Public Home page** (`/`) — anyone can view the profile: cover, avatar, name, bio, social icons (Facebook, X, GitHub), updated date, views, tabs. The social icons open their linked pages in a new browser tab.
- **Admin sign-in** (`/admin`) — an email + password form. There is no sign-up; accounts are created manually in the Firebase console.
- **Admin editor** (`/admin-editor`, signed-in only) — looks exactly like the Home page, but everything is editable:
  - Tap the **cover** or **avatar** to pick a new image from your device.
  - Tap the **name** or **bio** to edit the text in place.
  - Tap a **social icon** to set where that icon links.
  - A **Publish** pill appears in the icon row only after you actually change something. Publishing updates the live site immediately — the public Home page shows the new content as soon as it's saved.

## How it's built

- **Flutter (web only)** — Dart 3, Material 3, dark theme with a pure-black scaffold background.
- **Routing** — `go_router` with clean URLs (`/admin` instead of `#/admin`).
- **Firebase** — the app is connected to the `know-n1sk` Firebase project:
  - **Auth** (email + password) for the admin sign-in.
  - **Firestore** — the site content lives in the `admin/site` document.
  - **Storage** — cover and avatar images upload under `images/`.
  - **Hosting** — the site is served from https://know-n1sk.web.app.
  - Rules are set to **public read, signed-in write** for both Firestore and Storage.
- **Fonts** — Google Fonts for the username and bio; the profile name uses **Sekuya**, a display font bundled with the app (it isn't available through Google Fonts).

## Run it locally

```bash
flutter pub get
flutter run -d chrome
```

Open `http://localhost:<port>/` for the Home page, `/admin` for sign-in.

## Deploy to production

```bash
flutter build web
firebase deploy --only hosting
```

## Project layout

| Path | What it is |
|------|------------|
| `lib/main.dart` | App entry, Firebase init, route table, signed-in guard |
| `lib/pages/home_page.dart` | Public profile page |
| `lib/pages/admin_page.dart` | Admin email/password sign-in |
| `lib/pages/admin_editor_page.dart` | The editor (tap-to-edit replica of Home) |
| `lib/widgets/profile_view.dart` | The shared profile layout used by Home **and** the editor |
| `lib/site_content_service.dart` | Site content model + Firestore/Storage read & publish |
| `lib/auth_state.dart` | Signed-in state for routing |
| `assets/` | Placeholder cover/avatar art, bundled Sekuya font |
| `test/widget_test.dart` | Widget tests (run with `flutter test`) |

## Where the content lives

Publishing writes one document: `admin/site` in Firestore. It holds the cover/avatar image URLs, the name, the bio, and the three social links. Images themselves go to Firebase Storage under `images/`. If the document doesn't exist yet, the site falls back to the built-in placeholder art and text.

## Housekeeping notes

- `instruction.md` and `Completed.txt` in the repo root are the project's working documents — the self-updating "consciousness file" and the approved-tasks list. They're kept under version control so the project history is preserved.
