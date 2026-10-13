-- Run once on an existing TermuxQ Supabase project before syncing audit/SLA settings.
-- Safe to re-run.
alter table public.termuxq_records
  drop constraint if exists termuxq_records_record_type_check;
alter table public.termuxq_records
  add constraint termuxq_records_record_type_check
  check (record_type in ('asset', 'ticket', 'audit', 'setting'));


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
