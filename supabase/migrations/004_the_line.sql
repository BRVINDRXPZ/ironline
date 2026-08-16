-- THE LINE — append-only so history is preserved for the LINE history view
-- (docs/framework.md §8 Phase 2, MyGayLoverAtlas checklist). "Current" LINE
-- for a user × exercise is the row with the highest version.
create table public.the_line (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  predicted_weight numeric(6,1) not null,
  predicted_reps integer not null,
  confidence numeric(4,3) not null,
  baseline_sessions integer not null,
  calculated_at timestamptz not null default now(),
  version integer not null
);

create index the_line_user_exercise_idx on public.the_line(user_id, exercise_id, version desc);

alter table public.the_line enable row level security;

create policy "Users can view their own LINE history"
  on public.the_line for select
  using (auth.uid() = user_id);

create policy "Users can insert their own LINE rows"
  on public.the_line for insert
  with check (auth.uid() = user_id);
