-- PHASE 1 (additive) — one live duel per friend pair per exercise.
--
-- The previous draft keyed on (challenger_id, opponent_id, exercise_id),
-- which treats A→B and B→A as different matchups. Both could therefore be
-- live at once for the same exercise: two open challenges between the same
-- two people on the same lift, each resolving separately and each moving ELO.
-- For V1 that is the same matchup, and nothing in the framework asks for
-- simultaneous reciprocal challenges — Phase 4 describes "a duel" between
-- two friends, not a pair of crossing ones.
--
-- Keyed on the unordered pair via least/greatest, so direction stops
-- mattering. Both are immutable over uuid, which an expression index needs.
--
-- Still scoped to non-terminal states, so once a duel is completed,
-- declined, or expired it leaves the index and a rematch is allowed.
--
-- PREFLIGHT — fails if a reciprocal pair is already live. Check first:
--
--   select least(challenger_id, opponent_id)    as a,
--          greatest(challenger_id, opponent_id) as b,
--          exercise_id, count(*)
--     from public.duels
--    where status in ('pending', 'accepted')
--    group by 1, 2, 3
--   having count(*) > 1;
--
-- A non-empty result needs a human call on which duel survives; letting one
-- expire naturally is the least destructive option, since expiry is already
-- a terminal state that costs neither player ELO.

create unique index if not exists duels_active_matchup_uidx
  on public.duels (
    least(challenger_id, opponent_id),
    greatest(challenger_id, opponent_id),
    exercise_id
  )
  where status in ('pending', 'accepted');
