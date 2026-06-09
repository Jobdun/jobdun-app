-- 20260610000001_trade_unavailable_dates.sql
-- #13 availability calendar: let a trade block specific dates (booked / on
-- leave) on top of the boolean "open for work" + available_from already added
-- by 20260604000001_trade_search.sql.
--
-- Stored as a date[] on trade_profiles so it reuses the table's existing
-- owner-write / authenticated-read RLS — no new table or policies. The calendar
-- editor (trade) writes it; builders read it on the trade's profile.

ALTER TABLE public.trade_profiles
  ADD COLUMN IF NOT EXISTS unavailable_dates date[] NOT NULL DEFAULT '{}';

COMMENT ON COLUMN public.trade_profiles.unavailable_dates IS
  '#13 availability calendar: specific dates the trade has blocked off '
  '(booked / on leave). Date-only; default empty. Owner-write via the existing '
  'trade_profiles RLS; readable by authenticated users for the profile view.';
