// action: "send" | "accept" | "decline". If B sends a request while A
// already has one pending to B, this auto-accepts the existing row instead
// of creating a duplicate reverse request.
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

  const { action, friend_id } = await req.json();
  if (!action || !friend_id) {
    return new Response(JSON.stringify({ error: "action and friend_id are required" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const jsonHeaders = { ...corsHeaders, "Content-Type": "application/json" };

  if (action === "send") {
    if (friend_id === user.id) {
      return new Response(JSON.stringify({ error: "can't friend yourself" }), { status: 400, headers: jsonHeaders });
    }

    const { data: reverse } = await supabase
      .from("friendships")
      .select("id, status")
      .eq("user_id", friend_id)
      .eq("friend_id", user.id)
      .maybeSingle();

    if (reverse && reverse.status === "pending") {
      const { data: friendship, error } = await supabase
        .from("friendships")
        .update({ status: "accepted" })
        .eq("id", reverse.id)
        .select()
        .single();
      if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
      return new Response(JSON.stringify({ friendship, auto_accepted: true }), { headers: jsonHeaders });
    }

    const { data: friendship, error } = await supabase
      .from("friendships")
      .insert({ user_id: user.id, friend_id, status: "pending" })
      .select()
      .single();
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
    return new Response(JSON.stringify({ friendship }), { headers: jsonHeaders });
  }

  if (action === "accept" || action === "decline") {
    const { data: friendship, error } = await supabase
      .from("friendships")
      .update({ status: action === "accept" ? "accepted" : "declined" })
      .eq("user_id", friend_id)
      .eq("friend_id", user.id)
      .eq("status", "pending")
      .select()
      .single();
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 400, headers: jsonHeaders });
    return new Response(JSON.stringify({ friendship }), { headers: jsonHeaders });
  }

  return new Response(JSON.stringify({ error: "unknown action" }), { status: 400, headers: jsonHeaders });
});
