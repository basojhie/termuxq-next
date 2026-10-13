-- TermuxQ Next secure workspace schema (Supabase SQL Editor).
-- Records are shared by organization membership; credentials never belong in browser records.
create table if not exists public.termuxq_organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(trim(name)) between 2 and 80),
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create table if not exists public.termuxq_organization_members (
  organization_id uuid not null references public.termuxq_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  email text not null default '',
  role text not null check (role in ('admin', 'technician', 'viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id, user_id)
);
create index if not exists termuxq_org_members_user_idx on public.termuxq_organization_members(user_id, organization_id);

create or replace function public.termuxq_is_org_member(p_org_id uuid)
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.termuxq_organization_members m where m.organization_id=p_org_id and m.user_id=auth.uid()); $$;
create or replace function public.termuxq_has_org_role(p_org_id uuid, p_roles text[])
returns boolean language sql stable security definer set search_path = ''
as $$ select exists (select 1 from public.termuxq_organization_members m where m.organization_id=p_org_id and m.user_id=auth.uid() and m.role=any(p_roles)); $$;
revoke all on function public.termuxq_is_org_member(uuid) from public, anon;
revoke all on function public.termuxq_has_org_role(uuid, text[]) from public, anon;
grant execute on function public.termuxq_is_org_member(uuid) to authenticated;
grant execute on function public.termuxq_has_org_role(uuid, text[]) to authenticated;

create or replace function public.termuxq_create_org(p_name text)
returns uuid language plpgsql security definer set search_path = ''
as $$
declare v_user uuid := auth.uid(); v_email text := ''; v_org uuid; v_name text := trim(coalesce(p_name, ''));
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if char_length(v_name)<2 or char_length(v_name)>80 then raise exception 'Workspace name must be 2-80 characters'; end if;
  select coalesce(u.email,'') into v_email from auth.users u where u.id=v_user;
  insert into public.termuxq_organizations(name,created_by) values(v_name,v_user) returning id into v_org;
  insert into public.termuxq_organization_members(organization_id,user_id,email,role) values(v_org,v_user,v_email,'admin');
  return v_org;
end;
$$;
revoke all on function public.termuxq_create_org(text) from public, anon;
grant execute on function public.termuxq_create_org(text) to authenticated;

alter table public.termuxq_organizations enable row level security;
alter table public.termuxq_organization_members enable row level security;
revoke all on table public.termuxq_organizations from anon;
revoke all on table public.termuxq_organization_members from anon;
grant select on table public.termuxq_organizations to authenticated;
grant select on table public.termuxq_organization_members to authenticated;
revoke insert, update, delete on table public.termuxq_organizations from authenticated;
revoke insert, update, delete on table public.termuxq_organization_members from authenticated;
drop policy if exists "TermuxQ members read their organizations" on public.termuxq_organizations;
create policy "TermuxQ members read their organizations" on public.termuxq_organizations for select to authenticated using (public.termuxq_is_org_member(id));
drop policy if exists "TermuxQ members read workspace roster" on public.termuxq_organization_members;
create policy "TermuxQ members read workspace roster" on public.termuxq_organization_members for select to authenticated using (public.termuxq_is_org_member(organization_id));

create table if not exists public.termuxq_records (
  organization_id uuid not null references public.termuxq_organizations(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  record_type text not null check (record_type in ('asset', 'ticket', 'audit', 'setting')),
  record_id text not null check (char_length(record_id) between 1 and 120),
  payload jsonb,
  is_deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (organization_id, record_type, record_id),
  constraint termuxq_records_payload_consistency check ((is_deleted and payload is null) or (not is_deleted and payload is not null))
);
create index if not exists termuxq_records_org_type_idx on public.termuxq_records(organization_id,record_type);
create index if not exists termuxq_records_user_type_idx on public.termuxq_records(user_id,record_type);
alter table public.termuxq_records enable row level security;
revoke all on table public.termuxq_records from anon;
grant select, insert, update, delete on table public.termuxq_records to authenticated;
drop policy if exists "Users manage only their own TermuxQ records" on public.termuxq_records;
drop policy if exists "Workspace members read records" on public.termuxq_records;
drop policy if exists "Workspace technicians insert records" on public.termuxq_records;
drop policy if exists "Workspace technicians update records" on public.termuxq_records;
drop policy if exists "Workspace technicians delete records" on public.termuxq_records;
create policy "Workspace members read records" on public.termuxq_records for select to authenticated using (public.termuxq_is_org_member(organization_id));
create policy "Workspace technicians insert records" on public.termuxq_records for insert to authenticated with check (
  user_id=auth.uid() and public.termuxq_has_org_role(organization_id,array['admin','technician'])
  and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin']))
);
create policy "Workspace technicians update records" on public.termuxq_records for update to authenticated
using (public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])))
with check (user_id=auth.uid() and public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])));
create policy "Workspace technicians delete records" on public.termuxq_records for delete to authenticated
using (public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])));

create or replace function public.termuxq_set_updated_at()
returns trigger language plpgsql set search_path = ''
as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists termuxq_records_updated_at on public.termuxq_records;
create trigger termuxq_records_updated_at before update on public.termuxq_records for each row execute function public.termuxq_set_updated_at();

create table if not exists public.termuxq_notification_limits (
  user_id uuid primary key references auth.users(id) on delete cascade,
  window_started_at timestamptz not null default now(),
  window_count integer not null default 0 check (window_count>=0),
  last_sent_at timestamptz
);
alter table public.termuxq_notification_limits enable row level security;
revoke all on table public.termuxq_notification_limits from anon, authenticated;
grant all on table public.termuxq_notification_limits to service_role;
create or replace function public.termuxq_claim_notification_slot(p_user_id uuid)
returns table(allowed boolean,reason text) language plpgsql security definer set search_path = ''
as $$
declare v_window timestamptz; v_count integer; v_last timestamptz;
begin
 if auth.role()<>'service_role' then return query select false,'server_only'::text; return; end if;
 if p_user_id is null then return query select false,'user_required'::text; return; end if;
 insert into public.termuxq_notification_limits(user_id) values(p_user_id) on conflict(user_id) do nothing;
 select l.window_started_at,l.window_count,l.last_sent_at into v_window,v_count,v_last from public.termuxq_notification_limits l where l.user_id=p_user_id for update;
 if v_window<now()-interval '1 hour' then v_window:=now();v_count:=0;end if;
 if v_last is not null and v_last>now()-interval '1 minute' then return query select false,'cooldown'::text;return;end if;
 if v_count>=20 then return query select false,'hourly_limit'::text;return;end if;
 update public.termuxq_notification_limits l set window_started_at=v_window,window_count=v_count+1,last_sent_at=now() where l.user_id=p_user_id;
 return query select true,'ok'::text;
end; $$;
revoke all on function public.termuxq_claim_notification_slot(uuid) from public,anon,authenticated;
grant execute on function public.termuxq_claim_notification_slot(uuid) to service_role;
-- Never put a Supabase service_role or secret key in this public frontend.
