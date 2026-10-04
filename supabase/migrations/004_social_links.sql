-- ============================================================
-- KNOW NISK — Migration 004: Social links become a flexible list
--
-- BEFORE: three fixed columns — facebook_url, x_url, github_url —
--         holding only a link each, with the icon hard-coded in the app.
-- AFTER:  one "socials" column holding a LIST of slots, each slot being
--         { title, link, iconUrl }:
--           title   — the human name shown in the dialog (e.g. "GitHub")
--           link    — where the visitor goes when they pick it
--           iconUrl — a CUSTOM uploaded icon image (empty '' = fall back
--                     to the classic brand icon in the app)
--
-- Why a list (jsonb): the number of socials is no longer fixed at three.
-- The site can have any number of slots someday; the header shows the
-- first three plus a "+N" chip when there are more.
--
-- SAFETY: the old three columns are NOT dropped here. The currently
-- live site still reads them. A later cleanup migration retires them
-- once the new site is live and verified.
-- ============================================================

-- ── 1. THE NEW SHELF ────────────────────────────────────────
-- A jsonb column: the cell holds a whole little document (a list of
-- objects) instead of a single value. Starts as an empty list [].
alter table public.site_content
  add column if not exists socials jsonb not null default '[]'::jsonb;

-- ── 2. CARRY THE OLD LINKS OVER (first run only) ────────────
-- If the new list is still empty, build it from the old columns so no
-- link is lost. Titles get sensible defaults; iconUrl starts empty so
-- the app falls back to the classic Facebook/X/GitHub icons.
update public.site_content
set socials = jsonb_build_array(
  jsonb_build_object(
    'title', 'Facebook',
    'link', coalesce(facebook_url, ''),
    'iconUrl', ''
  ),
  jsonb_build_object(
    'title', 'X',
    'link', coalesce(x_url, ''),
    'iconUrl', ''
  ),
  jsonb_build_object(
    'title', 'GitHub',
    'link', coalesce(github_url, ''),
    'iconUrl', ''
  )
)
where jsonb_array_length(socials) = 0;

-- ── 3. THAT'S ALL ──────────────────────────────────────────
-- No RLS changes needed: the socials column lives inside site_content,
-- which already has its rulebook (public read, admin write only).
-- Realtime is already wired to the table — the list flows to every
-- open browser tab the moment you Publish.
