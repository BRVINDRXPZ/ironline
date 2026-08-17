create table public.rankings (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references public.users(id) on delete cascade,
  elo_rating integer not null default 1200,
  wins integer not null default 0,
  losses integer not null default 0,
  win_streak integer not null default 0,
  best_streak integer not null default 0,
  updated_at timestamptz not null default now()
);

alter table public.rankings enable row level security;

-- No insert/update policy for regular users — only the trigger below and
-- resolve-duel's service-role client are allowed to write ELO.
create policy "Users can view their own ranking"
  on public.rankings for select
  using (auth.uid() = user_id);

create trigger rankings_set_updated_at
  before update on public.rankings
  for each row execute function public.set_updated_at();

-- Every user starts at 1200 ELO (docs/framework.md §7) — created
-- automatically so resolve-duel never has to special-case a missing row.
create or replace function public.create_rankings_for_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.rankings (user_id) values (new.id);
  return new;
end;
$$;

create trigger users_create_rankings
  after insert on public.users
  for each row execute function public.create_rankings_for_new_user();
