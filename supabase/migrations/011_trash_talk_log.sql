create table public.trash_talk_log (
  id uuid primary key default gen_random_uuid(),
  duel_id uuid not null references public.duels(id) on delete cascade,
  sender_type text not null default 'ai' check (sender_type in ('ai', 'system')),
  message text not null,
  context text not null check (context in ('rest_period', 'duel_result', 'callout')),
  created_at timestamptz not null default now(),
  seen boolean not null default false
);

create index trash_talk_log_duel_id_idx on public.trash_talk_log(duel_id);

alter table public.trash_talk_log enable row level security;

create policy "Duel participants can view trash talk"
  on public.trash_talk_log for select
  using (exists (
    select 1 from public.duels d
    where d.id = trash_talk_log.duel_id
      and (d.challenger_id = auth.uid() or d.opponent_id = auth.uid())
  ));

-- No insert policy — entries are always written by generate-trash-talk's
-- service-role client. Marking a message seen is the one thing a
-- participant can do directly.
create policy "Duel participants can mark messages seen"
  on public.trash_talk_log for update
  using (exists (
    select 1 from public.duels d
    where d.id = trash_talk_log.duel_id
      and (d.challenger_id = auth.uid() or d.opponent_id = auth.uid())
  ));
