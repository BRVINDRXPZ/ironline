-- Workout sessions and camera-verified sets.
create table public.workout_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  status text not null default 'in_progress' check (status in ('in_progress', 'completed', 'abandoned'))
);

create index workout_sessions_user_id_idx on public.workout_sessions(user_id);

alter table public.workout_sessions enable row level security;

create policy "Users can view their own sessions"
  on public.workout_sessions for select
  using (auth.uid() = user_id);

create policy "Users can insert their own sessions"
  on public.workout_sessions for insert
  with check (auth.uid() = user_id);

create policy "Users can update their own sessions"
  on public.workout_sessions for update
  using (auth.uid() = user_id);

create table public.sets (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.workout_sessions(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  set_number integer not null,
  weight numeric(6,1) not null,
  reps_completed integer not null,
  reps_attempted integer not null,
  rom_pass_rate numeric(4,1),
  started_at timestamptz not null default now(),
  ended_at timestamptz,
  is_pr boolean not null default false
);

create index sets_session_id_idx on public.sets(session_id);
create index sets_exercise_id_idx on public.sets(exercise_id);

alter table public.sets enable row level security;

-- sets has no direct user_id — ownership flows through its session.
create policy "Users can view sets from their own sessions"
  on public.sets for select
  using (exists (
    select 1 from public.workout_sessions ws
    where ws.id = sets.session_id and ws.user_id = auth.uid()
  ));

create policy "Users can insert sets into their own sessions"
  on public.sets for insert
  with check (exists (
    select 1 from public.workout_sessions ws
    where ws.id = sets.session_id and ws.user_id = auth.uid()
  ));

create policy "Users can update sets from their own sessions"
  on public.sets for update
  using (exists (
    select 1 from public.workout_sessions ws
    where ws.id = sets.session_id and ws.user_id = auth.uid()
  ));
