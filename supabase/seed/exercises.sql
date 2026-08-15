-- Seed data for the 8 V1 exercises.
-- joint_config thresholds are starting estimates only — Phase 1 requires
-- tuning against real gym footage per docs/framework.md §12.

insert into public.exercises (name, muscle_group, joint_config, is_active) values

('Bench Press', 'Chest', '{
  "exercise": "Bench Press",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_elbow", "left_wrist"],
  "body_orientation": "supine",
  "rep_phases": {
    "bottom": { "elbow_angle_max": 95, "description": "Elbows bent to ~90 degrees, bar near chest" },
    "top": { "elbow_angle_min": 165, "description": "Arms near full extension" }
  },
  "rom_threshold": { "elbow_angle_at_bottom": 95, "rule": "elbow_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "top", "sequence": ["top", "bottom", "top"], "completion": "reaching top after valid bottom = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Barbell Row', 'Back', '{
  "exercise": "Barbell Row",
  "camera_angle": "side",
  "primary_joints": ["left_hip", "left_shoulder", "left_elbow"],
  "body_orientation": "hinged",
  "rep_phases": {
    "bottom": { "elbow_angle_min": 160, "description": "Arms hanging, full extension" },
    "top": { "elbow_angle_max": 60, "description": "Bar pulled to torso" }
  },
  "rom_threshold": { "elbow_angle_at_top": 60, "rule": "elbow_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "bottom", "sequence": ["bottom", "top", "bottom"], "completion": "reaching bottom after valid top = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Overhead Press', 'Shoulders', '{
  "exercise": "Overhead Press",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_elbow", "left_wrist"],
  "body_orientation": "standing",
  "rep_phases": {
    "bottom": { "elbow_angle_max": 90, "description": "Bar at shoulders" },
    "top": { "elbow_angle_min": 165, "description": "Full lockout overhead" }
  },
  "rom_threshold": { "elbow_angle_at_top": 165, "rule": "elbow_angle must reach >= threshold to count as full ROM" },
  "rep_state_machine": { "start": "bottom", "sequence": ["bottom", "top", "bottom"], "completion": "reaching bottom after valid top = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Barbell Squat', 'Quads', '{
  "exercise": "Barbell Squat",
  "camera_angle": "side",
  "primary_joints": ["left_hip", "left_knee", "left_ankle"],
  "body_orientation": "standing",
  "rep_phases": {
    "bottom": { "knee_angle_max": 90, "description": "Hip crease below knee" },
    "top": { "knee_angle_min": 165, "description": "Full standing" }
  },
  "rom_threshold": { "knee_angle_at_bottom": 90, "rule": "knee_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "top", "sequence": ["top", "bottom", "top"], "completion": "reaching top after valid bottom = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Deadlift', 'Hams/Glutes', '{
  "exercise": "Deadlift",
  "camera_angle": "side",
  "primary_joints": ["left_hip", "left_knee", "left_shoulder"],
  "body_orientation": "standing",
  "rep_phases": {
    "bottom": { "hip_angle_max": 45, "description": "Bar on floor, hips bent" },
    "top": { "hip_angle_min": 165, "description": "Full hip extension/lockout" }
  },
  "rom_threshold": { "hip_angle_at_top": 165, "rule": "hip_angle must reach >= threshold to count as full ROM" },
  "rep_state_machine": { "start": "bottom", "sequence": ["bottom", "top", "bottom"], "completion": "reaching bottom after valid top = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Barbell Curl', 'Biceps', '{
  "exercise": "Barbell Curl",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_elbow", "left_wrist"],
  "body_orientation": "standing",
  "rep_phases": {
    "bottom": { "elbow_angle_min": 160, "description": "Full arm extension" },
    "top": { "elbow_angle_max": 40, "description": "Full contraction" }
  },
  "rom_threshold": { "elbow_angle_at_top": 40, "rule": "elbow_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "bottom", "sequence": ["bottom", "top", "bottom"], "completion": "reaching bottom after valid top = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Skull Crushers', 'Triceps', '{
  "exercise": "Skull Crushers",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_elbow", "left_wrist"],
  "body_orientation": "supine",
  "rep_phases": {
    "bottom": { "elbow_angle_max": 90, "description": "Elbows bent to ~90 degrees" },
    "top": { "elbow_angle_min": 165, "description": "Full extension" }
  },
  "rom_threshold": { "elbow_angle_at_bottom": 90, "rule": "elbow_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "top", "sequence": ["top", "bottom", "top"], "completion": "reaching top after valid bottom = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true),

('Hanging Leg Raises', 'Core', '{
  "exercise": "Hanging Leg Raises",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_hip", "left_knee"],
  "body_orientation": "hanging",
  "rep_phases": {
    "bottom": { "hip_angle_min": 165, "description": "Legs hanging straight down" },
    "top": { "hip_angle_max": 90, "description": "Legs at/above 90 degree hip flexion" }
  },
  "rom_threshold": { "hip_angle_at_top": 90, "rule": "hip_angle must reach <= threshold to count as full ROM" },
  "rep_state_machine": { "start": "bottom", "sequence": ["bottom", "top", "bottom"], "completion": "reaching bottom after valid top = 1 rep" },
  "noise_filters": { "min_rep_duration_ms": 800, "max_rep_duration_ms": 8000, "joint_confidence_threshold": 0.5 }
}'::jsonb, true);
