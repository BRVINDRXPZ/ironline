create table public.duels (
  id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references public.users(id) on delete cascade,
  opponent_id uuid not null references public.users(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'in_progress', 'completed', 'expired')),
  challenger_set_id uuid references public.sets(id),
  opponent_set_id uuid references public.sets(id),
  challenger_line_score numeric(6,2),
  opponent_line_score numeric(6,2),
  winner_id uuid references public.users(id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '48 hours'),
  updated_at timestamptz not null default now(),
  check (challenger_id != opponent_id)
);

create index duels_challenger_id_idx on public.duels(challenger_id);
create index duels_opponent_id_idx on public.duels(opponent_id);
create index duels_status_expires_idx on public.duels(status, expires_at);

alter table public.duels enable row level security;

create policy "Participants can view their duels"
  on public.duels for select
  using (auth.uid() = challenger_id or auth.uid() = opponent_id);

create policy "Challenger can create a duel"
  on public.duels for insert
  with check (auth.uid() = challenger_id);

create policy "Opponent can respond to and resolve a duel"
  on public.duels for update
  using (auth.uid() = opponent_id);

create trigger duels_set_updated_at
  before update on public.duels
  for each row execute function public.set_updated_at();

-- Expiry is just a status flip, so it runs directly on a schedule rather
-- than through a cron-triggered Edge Function.
create extension if not exists pg_cron;

select cron.schedule(
  'expire-duels',
  '*/15 * * * *',
  $$ update public.duels set status = 'expired'
     where status in ('pending', 'accepted') and expires_at < now(); $$
);
