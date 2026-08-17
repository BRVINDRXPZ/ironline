// Challenger references a set they already saved, picks an opponent +
// exercise, and creates the duel. challenger_line_score is computed now;
// opponent_line_score/winner are filled in by resolve-duel.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax } from "../_shared/line.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
  );

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: jsonHeaders });
  }

  const { opponent_id, exercise_id, set_id } = await req.json();
  if (!opponent_id || !exercise_id || !set_id) {
    return new Response(JSON.stringify({ error: "opponent_id, exercise_id, and set_id are required" }), { status: 400, headers: jsonHeaders });
  }
  if (opponent_id === user.id) {
    return new Response(JSON.stringify({ error: "can't duel yourself" }), { status: 400, headers: jsonHeaders });
  }

  // RLS already scopes this to the caller's own sets.
  const { data: set, error: setError } = await supabase
    .from("sets")
    .select("weight, reps_completed, exercise_id")
    .eq("id", set_id)
    .eq("exercise_id", exercise_id)
    .single();

  if (setError || !set) {
    return new Response(JSON.stringify({ error: "set not found for this exercise" }), { status: 400, headers: jsonHeaders });
  }

  const { data: line } = await supabase
    .from("the_line")
    .select("predicted_weight, predicted_reps")
    .eq("exercise_id", exercise_id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  let challengerLineScore: number | null = null;
  if (line) {
    const actual = estimatedOneRepMax(set.weight, set.reps_completed);
    const predicted = estimatedOneRepMax(line.predicted_weight, line.predicted_reps);
    challengerLineScore = ((actual - predicted) / predicted) * 100;
  }

  const { data: duel, error } = await supabase
    .from("duels")
    .insert({
      challenger_id: user.id,
      opponent_id,
      exercise_id,
      challenger_set_id: set_id,
      challenger_line_score: challengerLineScore,
      status: "pending",
    })
    .select()
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
  }

  return new Response(JSON.stringify({ duel }), { headers: jsonHeaders });
});
