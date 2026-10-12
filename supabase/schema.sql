-- TermuxQ Next shared sync table (Supabase SQL Editor)
-- Only authenticated users may access their own rows.

create table if not exists public.termuxq_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null check (record_type in ('asset', 'ticket')),
  record_id text not null check (char_length(record_id) between 1 and 120),
  payload jsonb,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, record_type, record_id),
  constraint termuxq_records_payload_consistency
    check ((is_deleted and payload is null) or (not is_deleted and payload is not null))
);

create index if not exists termuxq_records_user_type_idx
  on public.termuxq_records (user_id, record_type);

alter table public.termuxq_records enable row level security;
revoke all on table public.termuxq_records from anon;
grant select, insert, update, delete on public.termuxq_records to authenticated;

drop policy if exists "Users manage only their own TermuxQ records" on public.termuxq_records;
create policy "Users manage only their own TermuxQ records"
  on public.termuxq_records for all to authenticated
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.termuxq_set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists termuxq_records_updated_at on public.termuxq_records;
create trigger termuxq_records_updated_at
before update on public.termuxq_records
for each row execute function public.termuxq_set_updated_at();

-- Never put a Supabase service_role or secret key in this public frontend.
