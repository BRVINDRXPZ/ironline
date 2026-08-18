// Returns a friend's recent completed sessions (with PR flags). Service
// role: normal RLS only lets you read your own workout_sessions/sets, so
// this verifies the friendship server-side, then reads on the caller's
// behalf.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

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

  const friendId = new URL(req.url).searchParams.get("friend_id");
  const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (!friendId || !uuidPattern.test(friendId)) {
    return new Response(JSON.stringify({ error: "a valid friend_id is required" }), { status: 400, headers: jsonHeaders });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: friendship } = await admin
    .from("friendships")
    .select("id")
    .or(`and(user_id.eq.${user.id},friend_id.eq.${friendId}),and(user_id.eq.${friendId},friend_id.eq.${user.id})`)
    .eq("status", "accepted")
    .maybeSingle();

  if (!friendship) {
    return new Response(JSON.stringify({ error: "not friends with this user" }), { status: 403, headers: jsonHeaders });
  }

  const { data: sessions, error } = await admin
    .from("workout_sessions")
    .select("id, started_at, ended_at, status, sets(exercise_id, weight, reps_completed, is_pr)")
    .eq("user_id", friendId)
    .eq("status", "completed")
    .order("started_at", { ascending: false })
    .limit(10);

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
  }

  return new Response(JSON.stringify({ sessions }), { headers: jsonHeaders });
});
