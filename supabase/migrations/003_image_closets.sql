-- ============================================================
-- KNOW NISK — Migration 003: The image closets (Storage)
--
-- Two public buckets (public = anyone may view the files
-- inside by URL; uploads still require an admin login).
-- Buckets and their security live inside Supabase's own
-- `storage` schema — so this whole migration is plain SQL.
-- ============================================================

-- ── 1. Create the two buckets (public read) ────────────────
insert into storage.buckets (id, name, public)
values ('images', 'images', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('posts', 'posts', true)
on conflict (id) do nothing;

-- ── 2. Rulebook for the buckets ───────────────────────────
-- storage.objects = the master list of every stored file.
-- Was Firebase storage.rules: public read, admin-only write.

create policy "public can view profile images"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'images');

create policy "public can view post attachments"
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'posts');

create policy "admins can upload to buckets"
  on storage.objects
  for insert
  to authenticated
  with check (bucket_id in ('images', 'posts'));

create policy "admins can update files in buckets"
  on storage.objects
  for update
  to authenticated
  using (bucket_id in ('images', 'posts'))
  with check (bucket_id in ('images', 'posts'));

create policy "admins can delete files in buckets"
  on storage.objects
  for delete
  to authenticated
  using (bucket_id in ('images', 'posts'));
