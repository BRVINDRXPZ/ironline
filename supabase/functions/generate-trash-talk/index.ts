// Generates a trash-talk line for an active duel using a self-hosted,
// OpenAI-compatible chat endpoint (Ollama serving Qwen3.8-27B AD-IQ3_S,
// reachable via Tailscale Funnel). Configure via Supabase secrets:
//   LLM_API_BASE_URL  e.g. https://your-mac.tailXXXX.ts.net
//   LLM_MODEL         e.g. qwen3.8:27b-iq3_s
//   LLM_API_KEY       optional bearer token, if you put one in front of the tunnel
//
// Cosmetic feature — if the local endpoint is unreachable or unconfigured,
// this skips quietly rather than failing anything duel-related.
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

  const { duel_id, context } = await req.json();
  if (!duel_id || !["rest_period", "duel_result", "callout"].includes(context)) {
    return new Response(JSON.stringify({ error: "duel_id and a valid context are required" }), { status: 400, headers: jsonHeaders });
  }

  const { data: duel, error: duelError } = await supabase
    .from("duels")
    .select("challenger_id, opponent_id, challenger_line_score, opponent_line_score, exercises(name)")
    .eq("id", duel_id)
    .or(`challenger_id.eq.${user.id},opponent_id.eq.${user.id}`)
    .single();

  if (duelError || !duel) {
    return new Response(JSON.stringify({ error: "duel not found" }), { status: 400, headers: jsonHeaders });
  }

  const baseUrl = Deno.env.get("LLM_API_BASE_URL");
  const model = Deno.env.get("LLM_MODEL");
  if (!baseUrl || !model) {
    return new Response(JSON.stringify({ skipped: true, reason: "LLM not configured" }), { headers: jsonHeaders });
  }

  const exerciseName = (duel.exercises as { name?: string } | null)?.name ?? "the exercise";
  const prompt = `You're a hype-man coach for a gym app. Write ONE short, punchy trash-talk line ` +
    `(under 20 words, no emoji) for an ongoing ${exerciseName} duel. ` +
    `Challenger LINE score: ${duel.challenger_line_score ?? "n/a"}. ` +
    `Opponent LINE score: ${duel.opponent_line_score ?? "n/a"}. Context: ${context}.`;

  let message: string | undefined;
  try {
    const apiKey = Deno.env.get("LLM_API_KEY");
    const response = await fetch(`${baseUrl}/v1/chat/completions`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
      },
      body: JSON.stringify({
        model,
        messages: [{ role: "user", content: prompt }],
        max_tokens: 60,
        temperature: 0.9,
      }),
      signal: AbortSignal.timeout(8000),
    });

    if (!response.ok) {
      return new Response(JSON.stringify({ skipped: true, reason: "local model unreachable" }), { headers: jsonHeaders });
    }

    const completion = await response.json();
    message = completion.choices?.[0]?.message?.content?.trim();
  } catch {
    return new Response(JSON.stringify({ skipped: true, reason: "local model unreachable" }), { headers: jsonHeaders });
  }

  if (!message) {
    return new Response(JSON.stringify({ skipped: true, reason: "empty response" }), { headers: jsonHeaders });
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: entry, error: insertError } = await admin
    .from("trash_talk_log")
    .insert({ duel_id, sender_type: "ai", message, context })
    .select()
    .single();

  if (insertError) {
    return new Response(JSON.stringify({ error: insertError.message }), { status: 400, headers: jsonHeaders });
  }

  return new Response(JSON.stringify({ entry }), { headers: jsonHeaders });
});
