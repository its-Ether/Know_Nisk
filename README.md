# Know Nisk 💙

A personal profile website for **Nisk** — styled like an X/Twitter profile on a pure-black canvas: cover photo, avatar, name, bio, social icons, a live view counter, and a tabbed posts feed.

**Live site:** https://nisk.devs.surf

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
| Hosting | Vercel (static — serves the committed `build/web`) |
| Domain | `nisk.devs.surf` (subdomain via devs.surf / ByteLogic; CNAME → Vercel) |
| Source control | GitHub — `noxnisk-cmyk/Know_Nisk` (private) |

## How it works

All content lives in Postgres, in three tables:

- **`site_content`** — a single row holding the whole profile card (cover, avatar, name, bio, username, social links, updated date). Social links are a flexible `socials` JSON list of `{ title, link, iconUrl }`.
- **`site_stats`** — the site-wide view counter. It lives in its own row so publishing new content can never reset it.
- **`posts`** — one row per post: folder (the tab it sits under), text, up to 4 images, video/link, optional article cover, view count, and timestamps.

Around them:

- The admin signs in with **Supabase Auth** (email + password). Only signed-in admins can write anything.
- Every page subscribes to the tables through **Supabase Realtime** — a published change appears on the public page immediately, no refresh.
- Images upload to two **public Storage buckets**: `images` (cover + avatar + social icons) and `posts` (attachments).
- View counters increment through server-side functions (`increment_site_views()`, `increment_post_views()`) that can only ever do `+1` — anonymous visitors can pull the vending-machine lever, nothing more.
- Security model: **RLS everywhere** — public read for everyone, every write requires a signed-in admin.

## Supabase migrations

The backend's entire history is version-controlled in `supabase/migrations/`:

1. `001_create_tables.sql` — the three tables, RLS enabled, seeded rows.
2. `002_security_and_counters.sql` — the RLS rulebook, the two counter functions, Realtime wiring.
3. `003_image_closets.sql` — the two public Storage buckets and their policies.
4. `004_social_links.sql` — social links become a flexible `socials` JSON list, seeded from the old fixed columns.
5. `005_drop_legacy_social_columns.sql` — drops the now-unused `facebook_url` / `x_url` / `github_url` columns (run after the old Netlify site was retired).

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
| `lib/widgets/socials_dialog.dart` | Shared social-links viewer/editor dialog |
| `lib/auth_state.dart` | Signed-in state for routing |
| `assets/` | Placeholder cover/avatar art, the bundled Sekuya font, the site icon |
| `supabase/migrations/` | The backend's versioned history |
| `vercel.json` | Hosting config — output dir `build/web` + SPA rewrites (all routes → `index.html`) |
| `build/web/` | The built web app, committed on purpose so Vercel can serve it |
| `docs/history/` | Older Firebase-era project documents, kept for history only |

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

- **Content changes** (name, bio, images, posts, social links): sign in at `/admin`, edit, **Publish** — instant, no redeploy needed, thanks to Realtime.
- **Code changes**: edit → `flutter analyze` → `flutter build web` → commit the updated `build/web` → `git push` → Vercel redeploys (or click **Redeploy** in the Vercel dashboard).
  - Tip: keep commits small. A single ~43 MB push has failed before (curl 55 / HTTP 408); slicing the work into smaller commits worked.

## Hosting & deployment

- **Vercel** project `spacenisk/know_nisk`. It's a static deploy: the built site in `build/web` is committed to the repo, and `vercel.json` sets `outputDirectory` and rewrites all routes to `/index.html` (so `/admin` and `/post/...` survive a hard refresh).
- **Domain:** `nisk.devs.surf` points at Vercel via a CNAME. HTTPS is automatic.
- No environment variables are set anywhere (nothing to leak).

## History

This app began life as a Firebase project (Auth + Firestore + Storage + Hosting). On **2026-10-02** it was migrated end-to-end to Supabase: the backend was rebuilt from scratch as versioned SQL migrations, and every Firebase SDK call was replaced with `supabase_flutter`. It first went live on **Netlify** (`know-nisk.netlify.app`), then on **2026-10-04** moved to **Vercel** and its own domain, `nisk.devs.surf`. The old Netlify site was retired and the legacy social columns were dropped (migration 005).

Older documents from the Firebase era are kept in `docs/history/` for reference only — they no longer describe the live system.
