-- ============================================================
-- KNOW NISK — Migration 001: Create the tables (the house skeleton)
-- From: Firebase (Firestore documents)
-- To:   Supabase (PostgreSQL tables)
--
-- A "table" is like a spreadsheet: rows are records,
-- columns are the fields every record has.
-- This file lives in the repo forever, so the backend's
-- entire history is version-controlled — just like the code.
-- ============================================================

-- ── 1. THE PROFILE CARD ─────────────────────────────────────
-- (was the Firestore document: admin/site)
-- Exactly one row will ever exist, with id = 'site'.
create table if not exists public.site_content (
  id           text primary key default 'site',
  cover_url    text not null default '',   -- cover image URL ('' = placeholder art)
  avatar_url   text not null default '',
  name         text not null default '',
  bio          text not null default '',
  username     text not null default '',
  facebook_url text not null default '',
  x_url        text not null default '',
  github_url   text not null default '',
  updated_at   timestamptz                -- when the admin last published
);

-- ── 2. THE VISITOR COUNTER ──────────────────────────────────
-- (was the Firestore document: stats/site)
-- Lives in its OWN table so publishing the profile
-- can never accidentally reset the counter.
create table if not exists public.site_stats (
  id    text primary key default 'site',
  views bigint not null default 0        -- total site views; anyone can add +1
);

-- ── 3. THE POSTS FEED ───────────────────────────────────────
-- (was the Firestore collection: posts)
create table if not exists public.posts (
  id         uuid primary key default gen_random_uuid(), -- random unique ID per post
  folder     text not null default '',    -- which tab the post sits under
  text       text not null default '',    -- the post's text
  images     text[] not null default '{}',-- list of image URLs (up to 4)
  video_url  text not null default '',
  link_url   text not null default '',
  cover_url  text not null default '',    -- optional banner for long posts
  views      bigint not null default 0,   -- how many times the post was opened
  created_at timestamptz not null default now(), -- publish time (server fills it)
  updated_at timestamptz                  -- only set when a post is edited
);

-- ── Security: tables are born LOCKED ───────────────────────
-- Row Level Security (RLS): no rule = no access, for anyone.
-- The rulebook (policies) comes in migration 002.
alter table public.site_content enable row level security;
alter table public.site_stats   enable row level security;
alter table public.posts        enable row level security;

-- ── Seed the two single rows that always exist ─────────────
-- Empty strings are intentional: the app treats them as
-- "keep the placeholder art", exactly like the old version.
insert into public.site_content (id) values ('site') on conflict (id) do nothing;
insert into public.site_stats   (id) values ('site') on conflict (id) do nothing;
