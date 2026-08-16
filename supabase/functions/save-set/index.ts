// Inserts a completed set and flags it as a PR.
// PR = heaviest weight ever for this exercise (ties broken by more reps).
// A proper e1RM-based comparison belongs to THE LINE in Phase 2 — this is
// intentionally the simple V1 version.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

interface SaveSetBody {
  session_id: string;
  exercise_id: string;
  set_number: number;
  weight: number;
  reps_completed: number;
  reps_attempted: number;
  rom_pass_rate?: number;
  started_at: string;
  ended_at?: string;
}

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

  const body: SaveSetBody = await req.json();

  const { data: priorBest, error: priorError } = await supabase
    .from("sets")
    .select("weight, reps_completed")
    .eq("exercise_id", body.exercise_id)
    .order("weight", { ascending: false })
    .order("reps_completed", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (priorError) {
    return new Response(JSON.stringify({ error: priorError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const isPr = !priorBest ||
    body.weight > priorBest.weight ||
    (body.weight === priorBest.weight && body.reps_completed > priorBest.reps_completed);

  const { data: set, error } = await supabase
    .from("sets")
    .insert({ ...body, is_pr: isPr })
    .select()
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ set }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
