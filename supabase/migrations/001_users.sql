-- User profiles, extending Supabase auth.users
create table public.users (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique,
  apple_id text unique,
  display_name text,
  avatar_url text,
  height_inches integer,
  weight_lbs numeric(5,1),
  age integer,
  gender text check (gender in ('male', 'female', 'other')),
  training_experience text check (training_experience in ('beginner', 'intermediate', 'advanced')),
  training_goal text check (training_goal in ('strength', 'hypertrophy', 'general')),
  preferred_units text not null default 'lbs' check (preferred_units in ('lbs', 'kg')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.users enable row level security;

-- Phase 0: self-access only. Friends/crew features (Phase 3) will need a
-- broader select policy (e.g. friends can view each other's display_name/avatar).
create policy "Users can view their own profile"
  on public.users for select
  using (auth.uid() = id);

create policy "Users can insert their own profile"
  on public.users for insert
  with check (auth.uid() = id);

create policy "Users can update their own profile"
  on public.users for update
  using (auth.uid() = id);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger users_set_updated_at
  before update on public.users
  for each row execute function public.set_updated_at();
