-- Forward-only. Audit findings 5 and 6 — duel matchmaking and set integrity.
-- Enforced with constraints rather than only in the Edge Functions, so a
-- future caller (or a retried request) cannot route around the rule.

-- FINDING 6 (medium) — a set could back more than one competitive duel.
-- Nothing tied a set to a single duel, so one strong set could be replayed
-- to win repeatedly. For a product whose claim is verified performance,
-- that undermines the referee more than a wrong rep count would.
--
-- A set may appear at most once in each role. Partial indexes so the many
-- NULL opponent_set_id rows on pending duels don't collide.
create unique index if not exists duels_challenger_set_uidx
  on public.duels(challenger_set_id)
  where challenger_set_id is not null;

create unique index if not exists duels_opponent_set_uidx
  on public.duels(opponent_set_id)
  where opponent_set_id is not null;

-- FINDING 5 (medium) — duplicate active challenges.
-- Nothing stopped a challenger opening unlimited pending duels against the
-- same person for the same exercise. One live challenge per
-- (challenger, opponent, exercise) at a time.
--
-- Scoped to non-terminal states on purpose: once a duel is completed,
-- declined, or expired it leaves the index, so rematches work normally.
create unique index if not exists duels_active_matchup_uidx
  on public.duels(challenger_id, opponent_id, exercise_id)
  where status in ('pending', 'accepted');

-- Note on the remaining reuse gap: these two indexes are per-column, so a
-- set used as a challenger_set_id could in principle also appear as an
-- opponent_set_id on a different duel. Closing that needs a cross-column
-- exclusion or a join table, which is more machinery than the risk earns at
-- alpha scale — resolve-duel additionally requires the opponent's set to
-- postdate the duel, so the realistic replay path is already blocked. Left
-- documented rather than built.
