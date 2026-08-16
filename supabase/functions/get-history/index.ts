// Returns the current user's sets for a given exercise, most recent first.
// RLS on `sets` (via session ownership) scopes this to the caller automatically.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

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

  const exerciseId = new URL(req.url).searchParams.get("exercise_id");
  if (!exerciseId) {
    return new Response(JSON.stringify({ error: "exercise_id is required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: sets, error } = await supabase
    .from("sets")
    .select("id, session_id, set_number, weight, reps_completed, reps_attempted, rom_pass_rate, is_pr, started_at, ended_at")
    .eq("exercise_id", exerciseId)
    .order("started_at", { ascending: false });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ sets }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
