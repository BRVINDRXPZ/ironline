-- PHASE 1 (additive) — one competitive use per set, globally.
--
-- The previous draft used two partial unique indexes, one on
-- challenger_set_id and one on opponent_set_id. That only made a set unique
-- *within each role*: the same set could still be the challenger's set on one
-- duel and the opponent's set on another, which is exactly the replay the
-- rule is meant to stop. Uniqueness has to span both columns of both roles,
-- and no single-column index can express that.
--
-- A claims table keyed by set_id does. The primary key is the invariant: a
-- set id can appear at most once across every duel and every role. Inserts
-- go through a trigger on duels, so the claim and the duel write share one
-- transaction — a losing concurrent claim raises 23505 and takes the duel
-- write down with it, rather than leaving a duel pointing at a set someone
-- else already claimed.
--
-- PREFLIGHT — the backfill below fails if production already contains a set
-- used more than once. Run this first; a non-empty result must be resolved
-- deliberately, because collapsing it means voiding a recorded duel:
--
--   select set_id, count(*) from (
--     select challenger_set_id as set_id from public.duels where challenger_set_id is not null
--     union all
--     select opponent_set_id   as set_id from public.duels where opponent_set_id   is not null
--   ) s group by set_id having count(*) > 1;

create table if not exists public.duel_set_claims (
  set_id     uuid primary key references public.sets(id)  on delete cascade,
  duel_id    uuid not null      references public.duels(id) on delete cascade,
  role       text not null check (role in ('challenger', 'opponent')),
  claimed_at timestamptz not null default now()
);

create index if not exists duel_set_claims_duel_id_idx on public.duel_set_claims(duel_id);

alter table public.duel_set_claims enable row level security;

-- Bookkeeping, not user-facing. No policies at all: clients cannot read or
-- write it, and only the trigger (SECURITY DEFINER) and service role touch it.

-- Backfill existing duels so historical rows are protected by the same
-- invariant and cannot be replayed after this migration lands.
insert into public.duel_set_claims (set_id, duel_id, role)
select challenger_set_id, id, 'challenger'
  from public.duels
 where challenger_set_id is not null
on conflict (set_id) do nothing;

insert into public.duel_set_claims (set_id, duel_id, role)
select opponent_set_id, id, 'opponent'
  from public.duels
 where opponent_set_id is not null
on conflict (set_id) do nothing;

-- `on conflict do nothing` above is for the backfill only — it keeps this
-- migration applicable when history already contains a duplicate rather than
-- refusing to install the protection at all. The preflight query is what
-- surfaces those cases for a human decision. New claims below do NOT swallow
-- conflicts; they must fail loudly.
create or replace function public.claim_duel_sets()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.challenger_set_id is not null
     and (tg_op = 'INSERT' or new.challenger_set_id is distinct from old.challenger_set_id) then
    insert into public.duel_set_claims (set_id, duel_id, role)
    values (new.challenger_set_id, new.id, 'challenger');
  end if;

  if new.opponent_set_id is not null
     and (tg_op = 'INSERT' or new.opponent_set_id is distinct from old.opponent_set_id) then
    insert into public.duel_set_claims (set_id, duel_id, role)
    values (new.opponent_set_id, new.id, 'opponent');
  end if;

  return new;
end;
$$;

create trigger duels_claim_sets
  after insert or update of challenger_set_id, opponent_set_id on public.duels
  for each row execute function public.claim_duel_sets();
