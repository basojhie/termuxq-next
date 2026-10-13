-- Workspace/role model. Run after 20261013_ticket_workflow.sql on existing installations.
-- Existing record owners receive a personal workspace; payloads and tombstones are retained.
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
  role text not null check (role in ('admin','technician','viewer')),
  created_at timestamptz not null default now(),
  primary key (organization_id,user_id)
);
create index if not exists termuxq_org_members_user_idx on public.termuxq_organization_members(user_id,organization_id);
alter table public.termuxq_records add column if not exists organization_id uuid references public.termuxq_organizations(id) on delete cascade;

insert into public.termuxq_organizations(name,created_by)
select 'TermuxQ Personal', users.user_id from (select distinct user_id from public.termuxq_records where organization_id is null) users
where not exists (select 1 from public.termuxq_organizations o where o.created_by=users.user_id and o.name='TermuxQ Personal');
update public.termuxq_records r set organization_id=o.id from public.termuxq_organizations o
where r.organization_id is null and o.created_by=r.user_id and o.name='TermuxQ Personal';
insert into public.termuxq_organization_members(organization_id,user_id,email,role)
select o.id,o.created_by,coalesce(u.email,''),'admin' from public.termuxq_organizations o join auth.users u on u.id=o.created_by
where o.name='TermuxQ Personal' on conflict(organization_id,user_id) do nothing;

do $$ begin
 if exists(select 1 from pg_constraint where conrelid='public.termuxq_records'::regclass and contype='p') then
  execute (select 'alter table public.termuxq_records drop constraint '||quote_ident(conname) from pg_constraint where conrelid='public.termuxq_records'::regclass and contype='p' limit 1);
 end if;
end; $$;
alter table public.termuxq_records alter column organization_id set not null;
alter table public.termuxq_records add constraint termuxq_records_pkey primary key(organization_id,record_type,record_id);
create index if not exists termuxq_records_org_type_idx on public.termuxq_records(organization_id,record_type);
create index if not exists termuxq_records_user_type_idx on public.termuxq_records(user_id,record_type);

create or replace function public.termuxq_is_org_member(p_org_id uuid)
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.termuxq_organization_members m where m.organization_id=p_org_id and m.user_id=auth.uid()); $$;
create or replace function public.termuxq_has_org_role(p_org_id uuid,p_roles text[])
returns boolean language sql stable security definer set search_path=''
as $$ select exists(select 1 from public.termuxq_organization_members m where m.organization_id=p_org_id and m.user_id=auth.uid() and m.role=any(p_roles)); $$;
revoke all on function public.termuxq_is_org_member(uuid) from public,anon;
revoke all on function public.termuxq_has_org_role(uuid,text[]) from public,anon;
grant execute on function public.termuxq_is_org_member(uuid) to authenticated;
grant execute on function public.termuxq_has_org_role(uuid,text[]) to authenticated;
create or replace function public.termuxq_create_org(p_name text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare v_user uuid:=auth.uid(); v_email text:=''; v_org uuid; v_name text:=trim(coalesce(p_name,''));
begin
 if v_user is null then raise exception 'Authentication required';end if;
 if char_length(v_name)<2 or char_length(v_name)>80 then raise exception 'Workspace name must be 2-80 characters';end if;
 select coalesce(u.email,'') into v_email from auth.users u where u.id=v_user;
 insert into public.termuxq_organizations(name,created_by) values(v_name,v_user) returning id into v_org;
 insert into public.termuxq_organization_members(organization_id,user_id,email,role) values(v_org,v_user,v_email,'admin');
 return v_org;
end; $$;
revoke all on function public.termuxq_create_org(text) from public,anon;
grant execute on function public.termuxq_create_org(text) to authenticated;

alter table public.termuxq_organizations enable row level security;
alter table public.termuxq_organization_members enable row level security;
revoke all on table public.termuxq_organizations from anon;
revoke all on table public.termuxq_organization_members from anon;
grant select on table public.termuxq_organizations to authenticated;
grant select on table public.termuxq_organization_members to authenticated;
revoke insert,update,delete on table public.termuxq_organizations from authenticated;
revoke insert,update,delete on table public.termuxq_organization_members from authenticated;
drop policy if exists "Users manage only their own TermuxQ records" on public.termuxq_records;
drop policy if exists "TermuxQ members read their organizations" on public.termuxq_organizations;
create policy "TermuxQ members read their organizations" on public.termuxq_organizations for select to authenticated using(public.termuxq_is_org_member(id));
drop policy if exists "TermuxQ members read workspace roster" on public.termuxq_organization_members;
create policy "TermuxQ members read workspace roster" on public.termuxq_organization_members for select to authenticated using(public.termuxq_is_org_member(organization_id));
drop policy if exists "Workspace members read records" on public.termuxq_records;
drop policy if exists "Workspace technicians insert records" on public.termuxq_records;
drop policy if exists "Workspace technicians update records" on public.termuxq_records;
drop policy if exists "Workspace technicians delete records" on public.termuxq_records;
create policy "Workspace members read records" on public.termuxq_records for select to authenticated using(public.termuxq_is_org_member(organization_id));
create policy "Workspace technicians insert records" on public.termuxq_records for insert to authenticated with check(user_id=auth.uid() and public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])));
create policy "Workspace technicians update records" on public.termuxq_records for update to authenticated
using(public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])))
with check(user_id=auth.uid() and public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])));
create policy "Workspace technicians delete records" on public.termuxq_records for delete to authenticated using(public.termuxq_has_org_role(organization_id,array['admin','technician']) and (record_type<>'setting' or public.termuxq_has_org_role(organization_id,array['admin'])));
