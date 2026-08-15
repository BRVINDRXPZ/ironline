-- Exercise catalog and camera-recognition rules.
-- joint_config format documented in docs/framework.md §11.
create table public.exercises (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  muscle_group text not null,
  joint_config jsonb not null,
  is_active boolean not null default true
);

alter table public.exercises enable row level security;

-- Reference data: any authenticated user can read, only service_role can write.
create policy "Authenticated users can read exercises"
  on public.exercises for select
  to authenticated
  using (true);
