-- QA seed data. Assumes 4 auth.users already exist (created via Dashboard
-- → Authentication → Add User, "Auto Confirm User" checked):
--   qa1@ironline.test, qa2@ironline.test, qa3@ironline.test, qa4@ironline.test
-- Populates profiles, workout history (enough to activate THE LINE),
-- ghost records, a friendship, a crew, and a completed duel — so the app
-- isn't empty during QA/UI testing. Re-running is not idempotent; drop and
-- re-seed on a fresh set of test users if needed.

insert into public.users (id, email, display_name, height_inches, weight_lbs, age, gender, training_experience, training_goal, preferred_units)
values
  ('ecec1bc1-108d-4e58-a302-e6865f5fd568', 'qa1@ironline.test', 'QA One',   70, 185.0, 28, 'male',   'intermediate', 'strength',    'lbs'),
  ('5387f4fe-c3da-4a00-96c6-f519200dc1c9', 'qa2@ironline.test', 'QA Two',   65, 145.0, 25, 'female', 'intermediate', 'hypertrophy', 'lbs'),
  ('d3655840-2249-40b4-a80b-75ce9bddd7d9', 'qa3@ironline.test', 'QA Three', 72, 200.0, 32, 'male',   'advanced',     'strength',    'lbs'),
  ('43a49a7d-c4b8-42df-80f3-bef5796204a7', 'qa4@ironline.test', 'QA Four',  68, 160.0, 22, 'other',  'beginner',     'general',     'lbs')
on conflict (id) do nothing;

-- QA1: Bench Press history, 4 sessions (LINE activates at 3) with a PR on the last one.
do $$
declare
  bench_id uuid := (select id from public.exercises where name = 'Bench Press');
  sess_id uuid;
  i int;
begin
  for i in 1..4 loop
    insert into public.workout_sessions (user_id, started_at, ended_at, status)
    values (
      'ecec1bc1-108d-4e58-a302-e6865f5fd568',
      now() - (28 - i * 7) * interval '1 day',
      now() - (28 - i * 7) * interval '1 day' + interval '45 minutes',
      'completed'
    )
    returning id into sess_id;

    insert into public.sets (session_id, exercise_id, set_number, weight, reps_completed, reps_attempted, rom_pass_rate, started_at, ended_at, is_pr)
    values (
      sess_id, bench_id, 1, 155 + i * 5, 8, 8, 100,
      now() - (28 - i * 7) * interval '1 day',
      now() - (28 - i * 7) * interval '1 day' + interval '5 minutes',
      i = 4
    );
  end loop;
end $$;

insert into public.the_line (user_id, exercise_id, predicted_weight, predicted_reps, confidence, baseline_sessions, version)
values ('ecec1bc1-108d-4e58-a302-e6865f5fd568', (select id from public.exercises where name = 'Bench Press'), 175.0, 8, 0.4, 4, 1);

-- Ghost records for QA1's Bench Press sets — heaviest stays unbeaten (the current ghost to race).
with qa1_bench_sets as (
  select s.id, s.weight, s.reps_completed
  from public.sets s
  join public.workout_sessions ws on ws.id = s.session_id
  where ws.user_id = 'ecec1bc1-108d-4e58-a302-e6865f5fd568'
    and s.exercise_id = (select id from public.exercises where name = 'Bench Press')
),
ranked as (
  select *, row_number() over (order by weight desc) as rnk from qa1_bench_sets
)
insert into public.ghost_records (user_id, exercise_id, set_id, weight, reps, beaten)
select 'ecec1bc1-108d-4e58-a302-e6865f5fd568', (select id from public.exercises where name = 'Bench Press'), id, weight, reps_completed, rnk != 1
from ranked;

-- QA2: Squat history, 3 sessions (LINE just activated), plus one Bench Press
-- set so QA2 has a shared exercise with QA1 for the duel below.
do $$
declare
  squat_id uuid := (select id from public.exercises where name = 'Barbell Squat');
  bench_id uuid := (select id from public.exercises where name = 'Bench Press');
  sess_id uuid;
  i int;
begin
  for i in 1..3 loop
    insert into public.workout_sessions (user_id, started_at, ended_at, status)
    values (
      '5387f4fe-c3da-4a00-96c6-f519200dc1c9',
      now() - (21 - i * 7) * interval '1 day',
      now() - (21 - i * 7) * interval '1 day' + interval '50 minutes',
      'completed'
    )
    returning id into sess_id;

    insert into public.sets (session_id, exercise_id, set_number, weight, reps_completed, reps_attempted, rom_pass_rate, started_at, ended_at, is_pr)
    values (
      sess_id, squat_id, 1, 135 + i * 10, 5, 5, 100,
      now() - (21 - i * 7) * interval '1 day',
      now() - (21 - i * 7) * interval '1 day' + interval '5 minutes',
      i = 3
    );
  end loop;

  insert into public.workout_sessions (user_id, started_at, ended_at, status)
  values ('5387f4fe-c3da-4a00-96c6-f519200dc1c9', now() - interval '1 day', now() - interval '1 day' + interval '30 minutes', 'completed')
  returning id into sess_id;

  insert into public.sets (session_id, exercise_id, set_number, weight, reps_completed, reps_attempted, rom_pass_rate, started_at, ended_at, is_pr)
  values (sess_id, bench_id, 1, 95, 8, 8, 100, now() - interval '1 day', now() - interval '1 day' + interval '5 minutes', true);
end $$;

insert into public.the_line (user_id, exercise_id, predicted_weight, predicted_reps, confidence, baseline_sessions, version)
values ('5387f4fe-c3da-4a00-96c6-f519200dc1c9', (select id from public.exercises where name = 'Barbell Squat'), 150.0, 5, 0.3, 3, 1);

-- Friendship: QA1 <-> QA2 accepted, QA3 -> QA1 still pending (covers both UI states).
insert into public.friendships (user_id, friend_id, status)
values
  ('ecec1bc1-108d-4e58-a302-e6865f5fd568', '5387f4fe-c3da-4a00-96c6-f519200dc1c9', 'accepted'),
  ('d3655840-2249-40b4-a80b-75ce9bddd7d9', 'ecec1bc1-108d-4e58-a302-e6865f5fd568', 'pending');

-- Crew: QA1 creates it (auto-added as leader via trigger), QA2 and QA3 join as members.
do $$
declare
  crew_id uuid;
begin
  insert into public.crews (name, created_by)
  values ('QA Test Crew', 'ecec1bc1-108d-4e58-a302-e6865f5fd568')
  returning id into crew_id;

  insert into public.crew_members (crew_id, user_id, role)
  values
    (crew_id, '5387f4fe-c3da-4a00-96c6-f519200dc1c9', 'member'),
    (crew_id, 'd3655840-2249-40b4-a80b-75ce9bddd7d9', 'member');
end $$;

-- Completed duel: QA1 (challenger) vs QA2 (opponent) on Bench Press, QA1 wins.
do $$
declare
  bench_id uuid := (select id from public.exercises where name = 'Bench Press');
  challenger_set_id uuid;
  opponent_set_id uuid;
begin
  select s.id into challenger_set_id
  from public.sets s join public.workout_sessions ws on ws.id = s.session_id
  where ws.user_id = 'ecec1bc1-108d-4e58-a302-e6865f5fd568' and s.exercise_id = bench_id
  order by s.weight desc limit 1;

  select s.id into opponent_set_id
  from public.sets s join public.workout_sessions ws on ws.id = s.session_id
  where ws.user_id = '5387f4fe-c3da-4a00-96c6-f519200dc1c9' and s.exercise_id = bench_id
  order by s.weight desc limit 1;

  insert into public.duels (challenger_id, opponent_id, exercise_id, status, challenger_set_id, opponent_set_id, challenger_line_score, opponent_line_score, winner_id)
  values (
    'ecec1bc1-108d-4e58-a302-e6865f5fd568', '5387f4fe-c3da-4a00-96c6-f519200dc1c9', bench_id, 'completed',
    challenger_set_id, opponent_set_id, 8.2, -3.1, 'ecec1bc1-108d-4e58-a302-e6865f5fd568'
  );
end $$;
