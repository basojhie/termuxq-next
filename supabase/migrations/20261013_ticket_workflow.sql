-- Run once on an existing TermuxQ Supabase project before syncing audit/SLA settings.
-- Safe to re-run.
alter table public.termuxq_records
  drop constraint if exists termuxq_records_record_type_check;
alter table public.termuxq_records
  add constraint termuxq_records_record_type_check
  check (record_type in ('asset', 'ticket', 'audit', 'setting'));
