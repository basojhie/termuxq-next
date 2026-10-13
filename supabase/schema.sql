-- TermuxQ Next shared sync table (Supabase SQL Editor)
-- Only authenticated users may access their own rows.
-- record_type supports asset, ticket, audit, and setting records.

create table if not exists public.termuxq_records (
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null check (record_type in ('asset', 'ticket', 'audit', 'setting')),
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


-- Server-only rate limiter for the Telegram ticket-notification Edge Function.
create table if not exists public.termuxq_notification_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  window_count integer not null default 0 check (window_count >= 0),
  last_sent_at timestamptz
);
alter table public.termuxq_notification_limits enable row level security;
revoke all on table public.termuxq_notification_limits from anon, authenticated;
grant all on table public.termuxq_notification_limits to service_role;

create or replace function public.termuxq_claim_notification_slot(p_user_id uuid)
returns table(allowed boolean, reason text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_window timestamptz;
  v_count integer;
  v_last timestamptz;
begin
  if auth.role() <> 'service_role' then
    return query select false, 'server_only'::text;
    return;
  end if;
  if p_user_id is null then
    return query select false, 'user_required'::text;
    return;
  end if;
  insert into public.termuxq_notification_limits(user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;
  select l.window_started_at, l.window_count, l.last_sent_at
    into v_window, v_count, v_last
    from public.termuxq_notification_limits l
   where l.user_id = p_user_id
   for update;
  if v_window < now() - interval '1 hour' then
    v_window := now();
    v_count := 0;
  end if;
  if v_last is not null and v_last > now() - interval '1 minute' then
    return query select false, 'cooldown'::text;
    return;
  end if;
  if v_count >= 20 then
    return query select false, 'hourly_limit'::text;
    return;
  end if;
  update public.termuxq_notification_limits l
     set window_started_at = v_window,
         window_count = v_count + 1,
         last_sent_at = now()
   where l.user_id = p_user_id;
  return query select true, 'ok'::text;
end;
$$;
revoke all on function public.termuxq_claim_notification_slot(uuid) from public, anon, authenticated;
grant execute on function public.termuxq_claim_notification_slot(uuid) to service_role;
