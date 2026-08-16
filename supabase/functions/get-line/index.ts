// Returns the current (highest-version) LINE for user x exercise, or a
// baseline-countdown payload if fewer than 3 sessions exist yet.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const MIN_SESSIONS = 3;

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

  const { data: line, error } = await supabase
    .from("the_line")
    .select("*")
    .eq("exercise_id", exerciseId)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (line) {
    return new Response(JSON.stringify({ line }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const { data: sets } = await supabase
    .from("sets")
    .select("session_id")
    .eq("exercise_id", exerciseId);

  const sessionsCount = new Set((sets ?? []).map((s) => s.session_id)).size;

  return new Response(
    JSON.stringify({ baseline: true, sessions_remaining: Math.max(0, MIN_SESSIONS - sessionsCount) }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } },
  );
});
