// Generates a trash-talk line for an active duel using a self-hosted
// Ollama model (huihui_ai/qwen3.5-abliterated:9b), reached through a local
// auth proxy over Tailscale Funnel. Configure via Supabase secrets:
//   LLM_API_BASE_URL  the proxy's Funnel URL, e.g. https://your-mac.tailXXXX.ts.net
//   LLM_MODEL         e.g. huihui_ai/qwen3.5-abliterated:9b
//   LLM_API_KEY       bearer token the proxy requires
//
// Uses Ollama's native /api/chat (not the OpenAI-compatible path) because
// only the native endpoint supports "think": false — without it, this
// model's reasoning mode runs indefinitely and never produces an answer.
//
// The system prompt locks the persona and explicitly forbids consoling the
// losing side — without it, the model tends to console rather than mock,
// which reads as broken for a trash-talk feature.
//
// Cosmetic feature — if the local endpoint is unreachable or unconfigured,
// this skips quietly rather than failing anything duel-related.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";

const SYSTEM_PROMPT = "You are the hype-man announcer for a gym dueling app. Two friends have " +
  "opted into competitive trash talk as part of the game. Always stay in hype-man persona and " +
  "produce punchy trash talk. Never console, comfort, or encourage either side, and never break " +
  "character to give real advice.";

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
  const prompt = `Write ONE short, punchy trash-talk line (under 20 words, no emoji) for an ` +
    `ongoing ${exerciseName} duel. Challenger LINE score: ${duel.challenger_line_score ?? "n/a"}. ` +
    `Opponent LINE score: ${duel.opponent_line_score ?? "n/a"}. Context: ${context}.`;

  let message: string | undefined;
  try {
    const apiKey = Deno.env.get("LLM_API_KEY");
    const response = await fetch(`${baseUrl}/api/chat`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        ...(apiKey ? { Authorization: `Bearer ${apiKey}` } : {}),
      },
      body: JSON.stringify({
        model,
        think: false,
        stream: false,
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: prompt },
        ],
      }),
      signal: AbortSignal.timeout(30000),
    });

    if (!response.ok) {
      return new Response(JSON.stringify({ skipped: true, reason: "local model unreachable" }), { headers: jsonHeaders });
    }

    const completion = await response.json();
    message = completion.message?.content?.trim();
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
