// line_score = (actual_e1RM - predicted_e1RM) / predicted_e1RM x 100
// (docs/framework.md §6). Consumed by duels in Phase 4.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax } from "../_shared/line.ts";

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

  const { set_id } = await req.json();
  if (!set_id) {
    return new Response(JSON.stringify({ error: "set_id is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: set, error: setError } = await supabase
    .from("sets")
    .select("weight, reps_completed, exercise_id")
    .eq("id", set_id)
    .single();

  if (setError) {
    return new Response(JSON.stringify({ error: setError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: line, error: lineError } = await supabase
    .from("the_line")
    .select("predicted_weight, predicted_reps")
    .eq("exercise_id", set.exercise_id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (lineError) {
    return new Response(JSON.stringify({ error: lineError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!line) {
    return new Response(JSON.stringify({ error: "no active LINE for this exercise yet" }), {
      status: 404,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const actualE1RM = estimatedOneRepMax(set.weight, set.reps_completed);
  const predictedE1RM = estimatedOneRepMax(line.predicted_weight, line.predicted_reps);
  const lineScore = ((actualE1RM - predictedE1RM) / predictedE1RM) * 100;

  return new Response(JSON.stringify({ line_score: lineScore, beat: lineScore > 0 }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
