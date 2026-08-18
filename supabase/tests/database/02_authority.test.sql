-- Write authority: after 013/019/020/021 an authenticated client must not be
-- able to author competitive state directly. These assert the actual denial,
-- not the presence of a DROP POLICY line, which is all a static check sees.
begin;
select plan(19);

-- Real auth users, because public.users FKs to auth.users.
insert into auth.users (id, instance_id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at)
values ('11111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'a@test.local', '', now(), now(), now()),
       ('22222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000',
        'authenticated', 'authenticated', 'b@test.local', '', now(), now(), now());

insert into public.users (id, email, preferred_units)
values ('11111111-1111-1111-1111-111111111111', 'a@test.local', 'lbs'),
       ('22222222-2222-2222-2222-222222222222', 'b@test.local', 'lbs');

insert into public.exercises (id, name, muscle_group, joint_config)
values ('33333333-3333-3333-3333-333333333333', 'Test Press', 'Chest', '{}'::jsonb);

insert into public.workout_sessions (id, user_id, status)
values ('44444444-4444-4444-4444-444444444444', '11111111-1111-1111-1111-111111111111', 'completed');

insert into public.sets (id, session_id, exercise_id, set_number, weight, reps_completed, reps_attempted, started_at)
values ('55555555-5555-5555-5555-555555555555', '44444444-4444-4444-4444-444444444444',
        '33333333-3333-3333-3333-333333333333', 1, 100, 8, 8, now());

-- --------------------------------------------------------------- as a client
set local role authenticated;
set local request.jwt.claims to '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select throws_ok(
  $q$ insert into public.the_line (user_id, exercise_id, predicted_weight, predicted_reps, confidence, baseline_sessions, version)
      values ('11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333',100,8,0.5,3,1) $q$,
  '42501', null, '013: client cannot INSERT the_line');

select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, challenger_set_id, status)
      values ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',
              '33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555','pending') $q$,
  '42501', null, '019: client cannot INSERT duels');

select throws_ok(
  $q$ insert into public.sets (session_id, exercise_id, set_number, weight, reps_completed, reps_attempted, started_at)
      values ('44444444-4444-4444-4444-444444444444','33333333-3333-3333-3333-333333333333',2,999,99,99,now()) $q$,
  '42501', null, '020: client cannot INSERT sets');

-- An UPDATE with no matching policy filters to zero rows rather than erroring,
-- so assert the row is genuinely unchanged instead of expecting a throw.
select lives_ok(
  $q$ update public.sets set weight = 999 where id = '55555555-5555-5555-5555-555555555555' $q$,
  '020: client UPDATE on sets raises nothing');
select is(
  (select weight from public.sets where id = '55555555-5555-5555-5555-555555555555'),
  100::numeric(6,1),
  '020: ... and the set is genuinely unchanged');

select throws_ok(
  $q$ insert into public.ghost_records (user_id, exercise_id, set_id, weight, reps)
      values ('11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333',
              '55555555-5555-5555-5555-555555555555',100,8) $q$,
  '42501', null, '021: client cannot INSERT ghost_records');

-- Reads that must keep working.
select isnt_empty(
  $q$ select 1 from public.sets where id = '55555555-5555-5555-5555-555555555555' $q$,
  'owner can still SELECT their own sets');
select is_empty(
  $q$ select 1 from public.workout_sessions where user_id = '22222222-2222-2222-2222-222222222222' $q$,
  'a user still cannot SELECT another users sessions');

reset role;

-- --------------------------------------------------- resolver EXECUTE grants
select function_privs_are('public', 'resolve_duel',
  array['uuid','uuid','uuid','numeric','uuid'], 'service_role', array['EXECUTE'],
  '015: service_role can EXECUTE resolve_duel');
select function_privs_are('public', 'resolve_duel',
  array['uuid','uuid','uuid','numeric','uuid'], 'authenticated', array[]::text[],
  '015: authenticated cannot EXECUTE resolve_duel');
select function_privs_are('public', 'resolve_duel',
  array['uuid','uuid','uuid','numeric','uuid'], 'anon', array[]::text[],
  '015: anon cannot EXECUTE resolve_duel');

-- ----------------------------------------------------------------- constraints
select throws_ok(
  $q$ insert into public.the_line (user_id, exercise_id, predicted_weight, predicted_reps, confidence, baseline_sessions, version)
      select '11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333',100,8,0.5,3,1
      union all
      select '11111111-1111-1111-1111-111111111111','33333333-3333-3333-3333-333333333333',110,8,0.5,3,1 $q$,
  '23505', null, '013: (user, exercise, version) is unique');

insert into public.invite_codes (code, kind, created_by, max_uses, use_count)
values ('TESTCODE1', 'friend', '11111111-1111-1111-1111-111111111111', 1, 1);
select throws_ok(
  $q$ update public.invite_codes set use_count = 2 where code = 'TESTCODE1' $q$,
  '23514', null, '018: use_count cannot exceed max_uses');

-- 016: one competitive use per set, across BOTH roles.
insert into public.duels (id, challenger_id, opponent_id, exercise_id, challenger_set_id, status)
values ('66666666-6666-6666-6666-666666666666','11111111-1111-1111-1111-111111111111',
        '22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333',
        '55555555-5555-5555-5555-555555555555','pending');

select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, challenger_set_id, status)
      values ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222',
              '33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555','declined') $q$,
  '23505', null, '016: a set cannot be the challenger set on two duels');

select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, opponent_set_id, status)
      values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
              '33333333-3333-3333-3333-333333333333','55555555-5555-5555-5555-555555555555','declined') $q$,
  '23505', null, '016: a set claimed as challenger cannot be reused as opponent set');

-- 017: unordered pair, and every active state counts.
select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, status)
      values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
              '33333333-3333-3333-3333-333333333333','pending') $q$,
  '23505', null, '017: B to A collides with an active A to B on the same exercise');

update public.duels set status = 'accepted' where id = '66666666-6666-6666-6666-666666666666';
select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, status)
      values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
              '33333333-3333-3333-3333-333333333333','pending') $q$,
  '23505', null, '017: accepted also counts as active');

update public.duels set status = 'in_progress' where id = '66666666-6666-6666-6666-666666666666';
select throws_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, status)
      values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
              '33333333-3333-3333-3333-333333333333','pending') $q$,
  '23505', null, '017: in_progress also counts as active');

update public.duels set status = 'completed' where id = '66666666-6666-6666-6666-666666666666';
select lives_ok(
  $q$ insert into public.duels (challenger_id, opponent_id, exercise_id, status)
      values ('22222222-2222-2222-2222-222222222222','11111111-1111-1111-1111-111111111111',
              '33333333-3333-3333-3333-333333333333','pending') $q$,
  '017: a rematch is allowed once the duel reaches a terminal state');

select * from finish();
rollback;
