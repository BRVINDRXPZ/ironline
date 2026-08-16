-- THE LINE is competitive game state. Clients may read their own LINE history,
-- but only the calculate-line Edge Function (service role) should create rows.
drop policy if exists "Users can insert their own LINE rows" on public.the_line;

-- Prevent duplicate versions if calculate-line is invoked concurrently.
create unique index if not exists the_line_user_exercise_version_uidx
  on public.the_line(user_id, exercise_id, version);
