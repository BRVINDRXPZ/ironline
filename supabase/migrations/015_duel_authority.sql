-- Forward-only. Fixes two audit findings on the reconciled tree. 008_duels.sql
-- is applied production history and is deliberately left untouched.
--
-- FINDING 1 (high) — clients could author duel outcomes directly.
-- 008 granted "Opponent can respond to and resolve a duel" as
--   for update using (auth.uid() = opponent_id)
-- With no WITH CHECK, Postgres reuses USING as the check, so opponent_id
-- itself was safe — but every other column was writable. An opponent could
-- PATCH /duels?id=eq.<id> straight through PostgREST setting
-- winner_id = themselves and status = 'completed', bypassing resolve-duel
-- entirely. That contradicts the authority rule in docs/api-contracts.md.
--
-- Fix: remove client UPDATE authority from duels altogether. A column
-- blacklist in RLS would be fragile — every future column would default to
-- writable. With no UPDATE policy, RLS denies all client updates, and the
-- two legitimate transitions run server-side in Edge Functions that
-- authorize the caller first (respond-duel, resolve-duel). Clients keep
-- SELECT (their own duels) and INSERT (as challenger) from 008.
drop policy if exists "Opponent can respond to and resolve a duel" on public.duels;

-- FINDING 2 (high) — resolve-duel could double-apply ELO.
-- It read the duel with status='accepted', then updated without reasserting
-- status, so a retry or a simultaneous second request could both pass the
-- read and both run the ELO block. The two ranking updates were also
-- separate statements, so they could partially apply or interleave with
-- another duel completing for the same player.
--
-- Fix: one function, one transaction. The status transition is a
-- compare-and-swap that only fires on accepted -> completed, and ELO is
-- computed from ranking rows locked in this same transaction. A second
-- caller finds no row to transition and returns null, having changed
-- nothing. ELO is computed here rather than passed in so it can never be
-- derived from rankings that changed between read and write.
create or replace function public.resolve_duel(
  p_duel_id uuid,
  p_opponent_id uuid,
  p_set_id uuid,
  p_opponent_line_score numeric,
  p_winner_id uuid
)
returns public.duels
language plpgsql
security definer
set search_path = public
as $$
declare
  v_duel public.duels;
  v_challenger public.rankings;
  v_opponent public.rankings;
  k constant integer := 32;
  v_challenger_result numeric;
  v_opponent_result numeric;
  v_challenger_expected numeric;
  v_opponent_expected numeric;
begin
  -- Compare-and-swap. `status = 'accepted'` is reasserted at the
  -- authoritative write, not merely checked beforehand.
  update public.duels
     set opponent_set_id      = p_set_id,
         opponent_line_score  = p_opponent_line_score,
         winner_id            = p_winner_id,
         status               = 'completed'
   where id          = p_duel_id
     and opponent_id = p_opponent_id
     and status      = 'accepted'
  returning * into v_duel;

  -- Exactly-once: a retry or concurrent second request lands here and
  -- applies no ELO. Caller distinguishes this from success by the null.
  if v_duel.id is null then
    return null;
  end if;

  -- Lock both ranking rows in a stable order. Two duels sharing players and
  -- completing at the same moment would otherwise be able to deadlock.
  perform 1
     from public.rankings
    where user_id in (v_duel.challenger_id, v_duel.opponent_id)
    order by user_id
      for update;

  select * into v_challenger from public.rankings where user_id = v_duel.challenger_id;
  select * into v_opponent   from public.rankings where user_id = v_duel.opponent_id;

  -- A missing ranking row must not silently skip ELO while still reporting
  -- the duel completed. The trigger in 009 creates one per user, so this
  -- means the data is wrong; fail and roll the transition back with it.
  if v_challenger.user_id is null or v_opponent.user_id is null then
    raise exception 'missing ranking row for duel % participants', p_duel_id;
  end if;

  -- Draw when nobody won: both beat or both missed by the same margin.
  v_challenger_result := case
    when p_winner_id = v_duel.challenger_id then 1
    when p_winner_id = v_duel.opponent_id   then 0
    else 0.5
  end;
  v_opponent_result := 1 - v_challenger_result;

  v_challenger_expected := 1 / (1 + power(10, (v_opponent.elo_rating - v_challenger.elo_rating) / 400.0));
  v_opponent_expected   := 1 / (1 + power(10, (v_challenger.elo_rating - v_opponent.elo_rating) / 400.0));

  update public.rankings
     set elo_rating  = round(v_challenger.elo_rating + k * (v_challenger_result - v_challenger_expected)),
         wins        = v_challenger.wins   + case when v_challenger_result = 1 then 1 else 0 end,
         losses      = v_challenger.losses + case when v_challenger_result = 0 then 1 else 0 end,
         win_streak  = case when v_challenger_result = 1 then v_challenger.win_streak + 1 else 0 end,
         best_streak = greatest(
           v_challenger.best_streak,
           case when v_challenger_result = 1 then v_challenger.win_streak + 1 else 0 end
         )
   where user_id = v_duel.challenger_id;

  update public.rankings
     set elo_rating  = round(v_opponent.elo_rating + k * (v_opponent_result - v_opponent_expected)),
         wins        = v_opponent.wins   + case when v_opponent_result = 1 then 1 else 0 end,
         losses      = v_opponent.losses + case when v_opponent_result = 0 then 1 else 0 end,
         win_streak  = case when v_opponent_result = 1 then v_opponent.win_streak + 1 else 0 end,
         best_streak = greatest(
           v_opponent.best_streak,
           case when v_opponent_result = 1 then v_opponent.win_streak + 1 else 0 end
         )
   where user_id = v_duel.opponent_id;

  return v_duel;
end;
$$;

-- Only the service role calls this, from resolve-duel after it has verified
-- the caller. Revoking the default PUBLIC grant keeps it off the client API
-- surface; a SECURITY DEFINER function callable by anon/authenticated would
-- reintroduce the very authority hole this migration closes.
revoke all on function public.resolve_duel(uuid, uuid, uuid, numeric, uuid) from public;
revoke all on function public.resolve_duel(uuid, uuid, uuid, numeric, uuid) from anon, authenticated;
