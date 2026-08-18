create table public.ghost_records (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  set_id uuid not null references public.sets(id) on delete cascade,
  weight numeric(6,1) not null,
  reps integer not null,
  beaten boolean not null default false,
  beaten_by_set_id uuid references public.sets(id),
  created_at timestamptz not null default now()
);

create index ghost_records_user_exercise_idx on public.ghost_records(user_id, exercise_id, beaten);

alter table public.ghost_records enable row level security;

create policy "Users can view their own ghost records"
  on public.ghost_records for select
  using (auth.uid() = user_id);

create policy "Users can insert their own ghost records"
  on public.ghost_records for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own ghost records"
  on public.ghost_records for update
  using (auth.uid() = user_id);
