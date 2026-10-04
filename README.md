# Know Nisk 💙

A personal profile website for **Nisk** — styled like an X/Twitter profile on a pure-black canvas: cover photo, avatar, name, bio, social icons, a live view counter, and a tabbed posts feed.

**Live site:**nisk.devs.surf

## What it does

- **Public Home page** (`/`) — anyone can view the profile: cover, avatar, name, bio, social links, updated date, site views, and tabs of posts.
- **Admin sign-in** (`/admin`) — email + password. There is no public sign-up; the admin account is created in the Supabase dashboard.
- **Admin editor** (`/admin-editor`) — a tap-to-edit replica of the Home page: tap the cover or avatar to pick a new image, tap the name or bio to edit text, set where each social icon points, compose posts. A **Publish** pill appears after any change — publishing goes live instantly, everywhere.
- **Shareable post pages** (`/post/:id`) — every post has its own URL.

## The stack

| Layer | Technology |
|---|---|
| Frontend | Flutter (web) — Dart 3, Material 3, `go_router`, Google Fonts |
| Backend | Supabase — PostgreSQL, Row Level Security, Realtime, Storage, Auth |
| Hosting | Netlify |
| Source control | GitHub — `noxnisk-cmyk/Know_Nisk` |

## How it works

All content lives in Postgres, in three tables:

- **`site_content`** — a single row holding the whole profile card (cover, avatar, name, bio, username, social links, updated date).
- **`site_stats`** — the site-wide view counter. It lives in its own row so publishing new content can never reset it.
- **`posts`** — one row per post: folder (the tab it sits under), text, up to 4 images, video/link, optional article cover, view count, and timestamps.

Around them:

- The admin signs in with **Supabase Auth** (email + password). Only signed-in admins can write anything.
- Every page subscribes to the tables through **Supabase Realtime** — a published change appears on the public page immediately, no refresh.
- Images upload to two **public Storage buckets**: `images` (cover + avatar) and `posts` (attachments).
- View counters increment through server-side functions (`increment_site_views()`, `increment_post_views()`) that can only ever do `+1` — anonymous visitors can pull the vending-machine lever, nothing more.
- Security model: **RLS everywhere** — public read for everyone, every write requires a signed-in admin.

## Supabase migrations

The backend's entire history is version-controlled in `supabase/migrations/`:

1. `001_create_tables.sql` — the three tables, RLS enabled, seeded rows.
2. `002_security_and_counters.sql` — the RLS rulebook, the two counter functions, Realtime wiring.
3. `003_image_closets.sql` — the two public Storage buckets and their policies.

## Project layout

| Path | What it is |
|---|---|
| `lib/main.dart` | App entry, Supabase init, route table, signed-in guard |
| `lib/pages/home_page.dart` | The public profile page |
| `lib/pages/admin_page.dart` | Admin sign-in (Supabase Auth) |
| `lib/pages/admin_editor_page.dart` | The tap-to-edit editor |
| `lib/pages/post_composer_page.dart` | Post composer |
| `lib/pages/post_detail_page.dart` | The shareable full-post page |
| `lib/site_content_service.dart` | Profile content model + read/publish |
| `lib/posts_service.dart` | Posts model + feed, create, edit, delete |
| `lib/auth_state.dart` | Signed-in state for routing |
| `assets/` | Placeholder cover/avatar art, the bundled Sekuya font |
| `supabase/migrations/` | The backend's versioned history |
| `web/_redirects` | SPA rewrite rule — keeps `/admin` and `/post/...` working on Netlify |

## Run locally

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install).

```bash
git clone https://github.com/noxnisk-cmyk/Know_Nisk.git
cd Know_Nisk
flutter pub get
flutter run -d edge     # or: -d chrome / -d web-server
```

The app talks to the live Supabase backend, so a local run reads (and, when signed in, writes) real data. Sign in at `/admin`.

## Updating the site

- **Content changes** (name, bio, images, posts): sign in at `/admin`, edit, **Publish** — instant, no redeploy needed, thanks to Realtime.
- **Code changes**: edit → test locally → `flutter build web --release` → Netlify → the site → **Deploys** → drag the `build/web` folder onto the drop zone → live in ~15 seconds. Every deploy is kept; any previous one can be re-published with one click (a rollback time machine).

## Custom domain

Planned. Netlify → Domain management → Add custom domain → point the DNS records at the Netlify site. HTTPS is automatic and free.

## History

This app began life as a Firebase project (Auth + Firestore + Storage + Hosting) by the same author. On **2026-10-02** it was migrated end-to-end to Supabase: the backend was rebuilt from scratch as versioned SQL migrations, every Firebase SDK call was replaced with `supabase_flutter`, and the site went live on Netlify.
