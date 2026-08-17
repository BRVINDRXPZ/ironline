-- Phase 5 performance audit: crew_members' PK (crew_id, user_id) covers
-- "list this crew's members" but not "list my crews" — the frontend crew
-- screen needs the latter, which would otherwise force a full table scan.
create index crew_members_user_id_idx on public.crew_members(user_id);
