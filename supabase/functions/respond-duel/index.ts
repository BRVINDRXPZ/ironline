// Opponent accepts or declines a pending duel. Declining is terminal —
// no ELO change (docs/framework.md §7).
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

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

  const { duel_id, action } = await req.json();
  if (!duel_id || !["accept", "decline"].includes(action)) {
    return new Response(JSON.stringify({ error: "duel_id and action (accept/decline) are required" }), { status: 400, headers: jsonHeaders });
  }

  const { data: duel, error } = await supabase
    .from("duels")
    .update({ status: action === "accept" ? "accepted" : "declined" })
    .eq("id", duel_id)
    .eq("opponent_id", user.id)
    .eq("status", "pending")
    .select()
    .single();

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
  }

  return new Response(JSON.stringify({ duel }), { headers: jsonHeaders });
});
