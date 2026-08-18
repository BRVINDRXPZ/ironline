-- Migration bootstrap: a fresh database applied 001-021 and ended up with the
-- objects the reconciled system expects. This runs after `supabase db reset`,
-- so reaching this file at all already proves the chain applied cleanly.
begin;
select plan(31);

-- Tables from the applied production history plus the reconciliation.
select has_table('public', 'users',            'users exists');
select has_table('public', 'exercises',        'exercises exists');
select has_table('public', 'workout_sessions', 'workout_sessions exists');
select has_table('public', 'sets',             'sets exists');
select has_table('public', 'the_line',         'the_line exists');
select has_table('public', 'friendships',      'friendships exists');
select has_table('public', 'crews',            'crews exists');
select has_table('public', 'crew_members',     'crew_members exists');
select has_table('public', 'invite_codes',     'invite_codes exists');
select has_table('public', 'duels',            'duels exists');
select has_table('public', 'rankings',         'rankings exists');
select has_table('public', 'ghost_records',    'ghost_records exists');
select has_table('public', 'trash_talk_log',   'trash_talk_log exists');
select has_table('public', 'duel_set_claims',  '016 created duel_set_claims');

-- Functions.
select has_function('public', 'resolve_duel',     '015 created resolve_duel');
select has_function('public', 'claim_duel_sets',  '016 created the claim trigger function');
select has_function('public', 'is_crew_member',   'Phase 5 crew recursion guard survived');

-- Indexes / constraints introduced by the reconciliation.
select has_index('public', 'the_line', 'the_line_user_exercise_version_uidx', '013 unique LINE version');
select has_index('public', 'duels',    'duels_active_matchup_uidx',           '017 active matchup index');
select has_index('public', 'crew_members', 'crew_members_user_id_idx',        '012 Phase 5 index survived');
select col_is_pk('public', 'duel_set_claims', 'set_id', '016 keys claims on set_id alone');

select has_check('public', 'invite_codes', '018 added a use_count check constraint');

-- RLS is on everywhere it should be.
select is(relrowsecurity, true, 'RLS enabled on ' || c.relname)
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public'
   and c.relname in ('users','sets','the_line','duels','rankings','ghost_records','duel_set_claims','invite_codes','friendships');

select * from finish();
rollback;
