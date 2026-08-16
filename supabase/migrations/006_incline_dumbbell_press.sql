-- First playable exercise. Keep this separate from generic Bench Press so
-- camera thresholds and history are not mixed across materially different lifts.
insert into public.exercises (name, muscle_group, joint_config, is_active)
values (
  'Incline Dumbbell Press',
  'Chest',
  '{
    "exercise": "Incline Dumbbell Press",
    "camera_angle": "side",
    "primary_joints": ["shoulder", "elbow", "wrist"],
    "body_orientation": "incline_supine",
    "rep_phases": {
      "bottom": { "elbow_angle_max": 100, "description": "Dumbbells at full controlled depth" },
      "top": { "elbow_angle_min": 155, "description": "Arms near lockout" }
    },
    "rom_threshold": {
      "elbow_angle_at_bottom": 100,
      "rule": "elbow_angle must reach <= threshold to count as full ROM"
    },
    "rep_state_machine": {
      "start": "top",
      "sequence": ["top", "bottom", "top"],
      "completion": "reaching top after valid bottom = 1 verified rep"
    },
    "noise_filters": {
      "joint_confidence_threshold": 0.35,
      "median_window_frames": 5
    }
  }'::jsonb,
  true
)
on conflict (name) do update
set joint_config = excluded.joint_config,
    muscle_group = excluded.muscle_group,
    is_active = excluded.is_active;
