// Inserts a completed set and flags it as a PR.
// PR = heaviest weight ever for this exercise (ties broken by more reps).
// A proper e1RM-based comparison belongs to THE LINE in Phase 2 — this is
// intentionally the simple V1 version.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax } from "../_shared/line.ts";

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

  // 020 removes the client INSERT/UPDATE policies on `sets`, so the write
  // below goes through the service role. That policy was what previously
  // scoped a set to the caller's own session, so the check has to be made
  // explicitly here — otherwise moving to the service role would widen the
  // hole instead of closing it.
  //
  // Read with the caller's own JWT on purpose: RLS on workout_sessions means
  // a session id belonging to anyone else simply isn't visible, so this both
  // proves existence and proves ownership in one query.
  const { data: session, error: sessionError } = await supabase
    .from("workout_sessions")
    .select("id")
    .eq("id", body.session_id)
    .maybeSingle();

  if (sessionError) {
    return new Response(JSON.stringify({ error: sessionError.message }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  if (!session) {
    return new Response(JSON.stringify({ error: "session not found for this user" }), {
      status: 403,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

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

  // Service-role write: after 020 there is no client INSERT policy on sets.
  // Ownership was proven above by reading the session under the caller's JWT.
  // Note the prior-best read above deliberately stays on the caller's client
  // so is_pr is still computed against that user's own history only.
  const { data: set, error } = await admin
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

  // Ghost bookkeeping (docs/framework.md §8 Phase 4): every set becomes a
  // ghost record, and any of the user's prior unbeaten ghosts this set's
  // e1RM surpasses get marked beaten.
  const { data: priorGhosts } = await supabase
    .from("ghost_records")
    .select("id, weight, reps")
    .eq("exercise_id", body.exercise_id)
    .eq("beaten", false);

  const newE1RM = estimatedOneRepMax(body.weight, body.reps_completed);
  const beatenIds = (priorGhosts ?? [])
    .filter((g) => estimatedOneRepMax(g.weight, g.reps) < newE1RM)
    .map((g) => g.id);

  if (beatenIds.length > 0) {
    await supabase
      .from("ghost_records")
      .update({ beaten: true, beaten_by_set_id: set.id })
      .in("id", beatenIds);
  }

  await supabase.from("ghost_records").insert({
    user_id: user.id,
    exercise_id: body.exercise_id,
    set_id: set.id,
    weight: body.weight,
    reps: body.reps_completed,
  });

  return new Response(JSON.stringify({ set }), {
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
});
