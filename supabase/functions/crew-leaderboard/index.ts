// Ranks a crew's roster by each member's most recent line_score (their
// latest set's e1RM vs. their active LINE for that exercise). Service
// role: needs to read every member's sets/the_line, not just the caller's.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax } from "../_shared/line.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  const authedClient = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_ANON_KEY")!,
    { global: { headers: { Authorization: req.headers.get("Authorization")! } } },
  );
  const { data: { user }, error: authError } = await authedClient.auth.getUser();
  if (authError || !user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), { status: 401, headers: jsonHeaders });
  }

  const crewId = new URL(req.url).searchParams.get("crew_id");
  if (!crewId) {
    return new Response(JSON.stringify({ error: "crew_id is required" }), { status: 400, headers: jsonHeaders });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: membership } = await admin
    .from("crew_members")
    .select("user_id")
    .eq("crew_id", crewId)
    .eq("user_id", user.id)
    .maybeSingle();

  if (!membership) {
    return new Response(JSON.stringify({ error: "not a member of this crew" }), { status: 403, headers: jsonHeaders });
  }

  const { data: members, error: membersError } = await admin
    .from("crew_members")
    .select("user_id, role, users(display_name, avatar_url)")
    .eq("crew_id", crewId);

  if (membersError) {
    return new Response(JSON.stringify({ error: membersError.message }), { status: 400, headers: jsonHeaders });
  }

  const leaderboard = await Promise.all(
    (members ?? []).map(async (m) => {
      const { data: recentSet } = await admin
        .from("sets")
        .select("weight, reps_completed, exercise_id, started_at, workout_sessions!inner(user_id)")
        .eq("workout_sessions.user_id", m.user_id)
        .order("started_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      let lineScore: number | null = null;

      if (recentSet) {
        const { data: line } = await admin
          .from("the_line")
          .select("predicted_weight, predicted_reps")
          .eq("exercise_id", recentSet.exercise_id)
          .eq("user_id", m.user_id)
          .order("version", { ascending: false })
          .limit(1)
          .maybeSingle();

        if (line) {
          const actual = estimatedOneRepMax(recentSet.weight, recentSet.reps_completed);
          const predicted = estimatedOneRepMax(line.predicted_weight, line.predicted_reps);
          lineScore = ((actual - predicted) / predicted) * 100;
        }
      }

      return {
        user_id: m.user_id,
        display_name: (m.users as { display_name?: string } | null)?.display_name ?? null,
        role: m.role,
        line_score: lineScore,
      };
    }),
  );

  leaderboard.sort((a, b) => (b.line_score ?? -Infinity) - (a.line_score ?? -Infinity));

  return new Response(JSON.stringify({ leaderboard }), { headers: jsonHeaders });
});
