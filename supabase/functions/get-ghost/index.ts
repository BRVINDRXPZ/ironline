// Returns the caller's best unbeaten set for an exercise — the target to race.
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

  const exerciseId = new URL(req.url).searchParams.get("exercise_id");
  if (!exerciseId) {
    return new Response(JSON.stringify({ error: "exercise_id is required" }), { status: 400, headers: jsonHeaders });
  }

  const { data: candidates, error } = await supabase
    .from("ghost_records")
    .select("id, weight, reps, set_id, created_at")
    .eq("exercise_id", exerciseId)
    .eq("beaten", false);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
  }

  if (!candidates || candidates.length === 0) {
    return new Response(JSON.stringify({ ghost: null }), { headers: jsonHeaders });
  }

  const best = candidates.reduce((top, c) =>
    estimatedOneRepMax(c.weight, c.reps) > estimatedOneRepMax(top.weight, top.reps) ? c : top
  );

  return new Response(JSON.stringify({ ghost: best }), { headers: jsonHeaders });
});
