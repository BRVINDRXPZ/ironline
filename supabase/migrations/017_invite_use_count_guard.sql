-- Forward-only. Audit finding 4 (medium) — invite codes could exceed max_uses.
--
-- redeem-invite read use_count, compared it to max_uses, then later wrote
-- `use_count = <read value> + 1` as a literal. Two concurrent redemptions
-- both read 0, both passed the check, and both wrote 1 — so a single-use
-- code could be redeemed repeatedly. Writing a literal also meant a CHECK
-- constraint alone would not have caught it.
--
-- Fixed in two places. The Edge Function now increments with a conditional
-- expression (see supabase/functions/redeem-invite), which is atomic under
-- READ COMMITTED: the second transaction blocks on the row lock, re-evaluates
-- its WHERE against the committed value, and matches no rows.
--
-- This constraint is the backstop. It makes the invariant true of the table
-- itself, so any future writer — a new function, a manual fix, a migration —
-- cannot push use_count past the limit even if it forgets the conditional.
alter table public.invite_codes
  add constraint invite_codes_use_count_within_max
  check (max_uses is null or use_count <= max_uses);
