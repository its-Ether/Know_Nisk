-- ============================================================
-- KNOW NISK — Migration 002: The rulebook (RLS) + counter machines
--
-- Tables were born LOCKED (migration 001).
-- This file is the rulebook the bouncer reads, plus two
-- "vending machines" (functions) for the view counters.
-- ============================================================

-- ── 1. SITE CONTENT: everyone may READ, only admins may WRITE ──

create policy "public can read the site content"
  on public.site_content
  for select
  to anon, authenticated
  using (true);

create policy "admins can insert site content"
  on public.site_content
  for insert
  to authenticated
  with check (true);

create policy "admins can update site content"
  on public.site_content
  for update
  to authenticated
  using (true) with check (true);

create policy "admins can delete site content"
  on public.site_content
  for delete
  to authenticated
  using (true);

-- ── 2. SITE STATS: everyone may READ, only admins may WRITE ──

create policy "public can read the site stats"
  on public.site_stats
  for select
  to anon, authenticated
  using (true);

create policy "admins can insert site stats"
  on public.site_stats
  for insert
  to authenticated
  with check (true);

create policy "admins can update site stats"
  on public.site_stats
  for update
  to authenticated
  using (true) with check (true);

create policy "admins can delete site stats"
  on public.site_stats
  for delete
  to authenticated
  using (true);

-- ── 3. POSTS: everyone may READ, only admins may WRITE ──

create policy "public can read posts"
  on public.posts
  for select
  to anon, authenticated
  using (true);

create policy "admins can create posts"
  on public.posts
  for insert
  to authenticated
  with check (true);

create policy "admins can update posts"
  on public.posts
  for update
  to authenticated
  using (true) with check (true);

create policy "admins can delete posts"
  on public.posts
  for delete
  to authenticated
  using (true);

-- ── 4. THE VENDING MACHINES (counter functions) ─────────────
-- SECURITY DEFINER = the function runs with the powers of its
-- owner (the house architect), NOT the caller. Strangers can
-- pull the lever, but the machine only ever does "+1".

create or replace function public.increment_site_views()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.site_stats
     set views = views + 1
   where id = 'site';
end;
$$;

-- Strangers AND admins may pull this lever:
grant execute on function public.increment_site_views()
  to anon, authenticated;

create or replace function public.increment_post_views(p_post_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.posts
     set views = views + 1
   where id = p_post_id;
end;
$$;

grant execute on function public.increment_post_views(uuid)
  to anon, authenticated;

-- ── 5. LIVE UPDATES: open the wires (Lesson 5 preview) ─────
-- Realtime = Supabase's fire-alarm system. The app subscribes
-- to changes instead of polling. We open the wires for all
-- three tables now so we don't have to come back later.
alter publication supabase_realtime add table public.site_content;
alter publication supabase_realtime add table public.site_stats;
alter publication supabase_realtime add table public.posts;
