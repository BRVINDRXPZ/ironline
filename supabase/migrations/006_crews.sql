-- Crews and their membership. Cap is enforced at the DB level so it holds
-- regardless of entry path (direct join or via redeem-invite).
create table public.crews (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid not null references public.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  max_members integer not null default 5
);

create table public.crew_members (
  crew_id uuid not null references public.crews(id) on delete cascade,
  user_id uuid not null references public.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  role text not null default 'member' check (role in ('leader', 'member')),
  primary key (crew_id, user_id)
);

-- SECURITY DEFINER + pinned search_path: lets crew_members' own RLS policy
-- check membership without recursing into crew_members' own SELECT policy.
create or replace function public.is_crew_member(check_crew_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.crew_members
    where crew_id = check_crew_id and user_id = auth.uid()
  );
$$;

alter table public.crews enable row level security;
alter table public.crew_members enable row level security;

create policy "Members can view their crew"
  on public.crews for select
  using (public.is_crew_member(id));

create policy "Users can create crews"
  on public.crews for insert
  with check (auth.uid() = created_by);

create policy "Creator can disband their crew"
  on public.crews for delete
  using (auth.uid() = created_by);

create policy "Members can view their crew roster"
  on public.crew_members for select
  using (public.is_crew_member(crew_id));

create policy "Users can join a crew as themselves"
  on public.crew_members for insert
  with check (auth.uid() = user_id);

create policy "Users can leave a crew"
  on public.crew_members for delete
  using (auth.uid() = user_id);

-- Auto-add the creator as leader so a crew is never left without one.
create or replace function public.add_crew_creator_as_leader()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.crew_members (crew_id, user_id, role)
  values (new.id, new.created_by, 'leader');
  return new;
end;
$$;

create trigger crews_add_creator_as_leader
  after insert on public.crews
  for each row execute function public.add_crew_creator_as_leader();

-- Cap check runs as the row owner, not the inserting caller, so it can't
-- be starved by RLS visibility on crew_members.
create or replace function public.enforce_crew_cap()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  member_count integer;
  cap integer;
begin
  select count(*) into member_count from public.crew_members where crew_id = new.crew_id;
  select max_members into cap from public.crews where id = new.crew_id;
  if member_count >= cap then
    raise exception 'Crew is full (max % members)', cap;
  end if;
  return new;
end;
$$;

create trigger crew_members_enforce_cap
  before insert on public.crew_members
  for each row execute function public.enforce_crew_cap();

-- Live crew activity for Atlas's crew feed.
alter publication supabase_realtime add table public.crew_members;
alter publication supabase_realtime add table public.sets;
