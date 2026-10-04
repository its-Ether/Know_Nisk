-- 005_drop_legacy_social_columns.sql
-- Know_N1SK -- cleanup migration
--
-- WHY: In migration 004, the three fixed social columns (facebook_url, x_url,
-- github_url) were replaced by a flexible `socials` jsonb list of
-- { title, link, iconUrl } objects. The old columns are now dead weight and
-- are no longer read by any current code.
--
-- WHEN: Safe to run only AFTER the old Netlify site was retired
-- (know-nisk.netlify.app, deleted 2026-10-04), because that old code still
-- read these columns. The current Vercel site never reads them.
--
-- HOW: Supabase Dashboard -> SQL Editor -> paste -> Run.
-- Idempotent: `if exists` means re-running is harmless.

alter table public.site_content
  drop column if exists facebook_url,
  drop column if exists x_url,
  drop column if exists github_url;
