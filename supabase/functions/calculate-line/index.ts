// Recalculates THE LINE for a user × exercise. Called by the client right
// after a session is marked completed (framework §12: keep V1 simple — no
// DB webhook needed for this).
//
// docs/framework.md §6:
//   1. last N sets (max 30)
//   2. e1RM per set via Epley
//   3. recency weighting, half-life 14 days
//   4. LINE = weighted avg e1RM x 0.92
//   5. convert back to weight x reps using typical rep count
//   6. confidence = min(sessions / 10, 1.0)
//
// Adaptation (beat/miss the LINE 3x in a row) has no framework-specified
// constants — the +2%/70-30 blend below are simple, tunable V1 defaults.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax, predictedWeightFor } from "../_shared/line.ts";

const HALF_LIFE_DAYS = 14;
const LINE_MULTIPLIER = 0.92;
const MIN_SESSIONS = 3;
const BEAT_STREAK_BONUS = 1.02;
const MISS_STREAK_DAMPING = 0.3; // weight given to the new (lower) value

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { exercise_id } = await req.json();
  if (!exercise_id) {
    return new Response(JSON.stringify({ error: "exercise_id is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: sets, error: setsError } = await supabase
    .from("sets")
    .select("weight, reps_completed, session_id, started_at")
    .eq("exercise_id", exercise_id)
    .order("started_at", { ascending: false })
    .limit(30);

  if (setsError) {
    return new Response(JSON.stringify({ error: setsError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const sessionsCount = new Set((sets ?? []).map((s) => s.session_id)).size;

  if (sessionsCount < MIN_SESSIONS) {
    return new Response(
      JSON.stringify({ baseline: true, sessions_remaining: MIN_SESSIONS - sessionsCount }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } },
    );
  }

  const now = Date.now();
  let weightedSum = 0;
  let weightTotal = 0;
  let repsSum = 0;

  for (const s of sets!) {
    const e1RM = estimatedOneRepMax(s.weight, s.reps_completed);
    const ageDays = (now - new Date(s.started_at).getTime()) / 86_400_000;
    const recencyWeight = Math.pow(0.5, ageDays / HALF_LIFE_DAYS);
    weightedSum += e1RM * recencyWeight;
    weightTotal += recencyWeight;
    repsSum += s.reps_completed;
  }

  let lineE1RM = (weightedSum / weightTotal) * LINE_MULTIPLIER;
  const typicalReps = Math.max(1, Math.round(repsSum / sets!.length));

  const { data: previous } = await supabase
    .from("the_line")
    .select("predicted_weight, predicted_reps, version")
    .eq("exercise_id", exercise_id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (previous && sets!.length >= 3) {
    const prevE1RM = estimatedOneRepMax(previous.predicted_weight, previous.predicted_reps);
    const last3 = sets!.slice(0, 3).map((s) => estimatedOneRepMax(s.weight, s.reps_completed));
    const allBeat = last3.every((e) => e > prevE1RM);
    const allMissed = last3.every((e) => e < prevE1RM);

    if (allBeat) {
      lineE1RM *= BEAT_STREAK_BONUS;
    } else if (allMissed) {
      lineE1RM = prevE1RM * (1 - MISS_STREAK_DAMPING) + lineE1RM * MISS_STREAK_DAMPING;
    }
  }

  const predictedWeight = Math.round(predictedWeightFor(lineE1RM, typicalReps) * 10) / 10;
  const confidence = Math.min(sessionsCount / 10, 1.0);
  const version = (previous?.version ?? 0) + 1;

  const { data: line, error: insertError } = await supabase
    .from("the_line")
    .insert({
      user_id: user.id,
      exercise_id,
      predicted_weight: predictedWeight,
      predicted_reps: typicalReps,
      confidence,
      baseline_sessions: sessionsCount,
      version,
    })
    .select()
    .single();

  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ line }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
