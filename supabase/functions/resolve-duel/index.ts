// Opponent submits their set to resolve a duel: computes both
// line_scores, picks the winner (or draw), and updates both players' ELO
// in the same call. Kept atomic rather than three separate hops so a duel
// can't get stuck half-resolved if a later step fails.
import { createClient } from "jsr:@supabase/supabase-js@2";
import { corsHeaders } from "../_shared/cors.ts";
import { estimatedOneRepMax } from "../_shared/line.ts";
import { eloExpectedScore, eloNewRating } from "../_shared/elo.ts";

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

  const { duel_id, set_id } = await req.json();
  if (!duel_id || !set_id) {
    return new Response(JSON.stringify({ error: "duel_id and set_id are required" }), { status: 400, headers: jsonHeaders });
  }

  const { data: duel, error: duelError } = await supabase
    .from("duels")
    .select("*")
    .eq("id", duel_id)
    .eq("opponent_id", user.id)
    .eq("status", "accepted")
    .single();

  if (duelError || !duel) {
    return new Response(JSON.stringify({ error: "duel not found or not ready to resolve" }), { status: 400, headers: jsonHeaders });
  }

  const { data: opponentSet, error: setError } = await supabase
    .from("sets")
    .select("weight, reps_completed, exercise_id")
    .eq("id", set_id)
    .eq("exercise_id", duel.exercise_id)
    .single();

  if (setError || !opponentSet) {
    return new Response(JSON.stringify({ error: "set not found for this exercise" }), { status: 400, headers: jsonHeaders });
  }

  const { data: line } = await supabase
    .from("the_line")
    .select("predicted_weight, predicted_reps")
    .eq("exercise_id", duel.exercise_id)
    .order("version", { ascending: false })
    .limit(1)
    .maybeSingle();

  let opponentLineScore: number | null = null;
  if (line) {
    const actual = estimatedOneRepMax(opponentSet.weight, opponentSet.reps_completed);
    const predicted = estimatedOneRepMax(line.predicted_weight, line.predicted_reps);
    opponentLineScore = ((actual - predicted) / predicted) * 100;
  }

  // Higher line_score wins. If either side has no active LINE yet (still
  // in baseline), fall back to comparing raw e1RM so the duel can still resolve.
  let winnerId: string | null = null;
  const challengerScore = duel.challenger_line_score;
  if (challengerScore !== null && opponentLineScore !== null) {
    if (challengerScore > opponentLineScore) winnerId = duel.challenger_id;
    else if (opponentLineScore > challengerScore) winnerId = duel.opponent_id;
  } else {
    const { data: challengerSet } = await supabase
      .from("sets")
      .select("weight, reps_completed")
      .eq("id", duel.challenger_set_id)
      .single();
    const challengerE1RM = challengerSet ? estimatedOneRepMax(challengerSet.weight, challengerSet.reps_completed) : 0;
    const opponentE1RM = estimatedOneRepMax(opponentSet.weight, opponentSet.reps_completed);
    if (challengerE1RM > opponentE1RM) winnerId = duel.challenger_id;
    else if (opponentE1RM > challengerE1RM) winnerId = duel.opponent_id;
  }

  const { data: updatedDuel, error: updateError } = await supabase
    .from("duels")
    .update({
      opponent_set_id: set_id,
      opponent_line_score: opponentLineScore,
      winner_id: winnerId,
      status: "completed",
    })
    .eq("id", duel_id)
    .select()
    .single();

  if (updateError) {
    return new Response(JSON.stringify({ error: updateError.message }), { status: 400, headers: jsonHeaders });
  }

  // ELO needs to write both players' rankings rows, which RLS won't allow
  // under either player's own JWT — same pattern as friend-activity/crew-leaderboard.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: rankings } = await admin
    .from("rankings")
    .select("*")
    .in("user_id", [duel.challenger_id, duel.opponent_id]);

  const challengerRanking = rankings?.find((r) => r.user_id === duel.challenger_id);
  const opponentRanking = rankings?.find((r) => r.user_id === duel.opponent_id);

  if (challengerRanking && opponentRanking) {
    const challengerWon = winnerId === duel.challenger_id;
    const opponentWon = winnerId === duel.opponent_id;
    const challengerResult = challengerWon ? 1 : opponentWon ? 0 : 0.5;
    const opponentResult = 1 - challengerResult;

    const challengerExpected = eloExpectedScore(challengerRanking.elo_rating, opponentRanking.elo_rating);
    const opponentExpected = eloExpectedScore(opponentRanking.elo_rating, challengerRanking.elo_rating);

    const newChallengerElo = eloNewRating(challengerRanking.elo_rating, challengerExpected, challengerResult);
    const newOpponentElo = eloNewRating(opponentRanking.elo_rating, opponentExpected, opponentResult);

    const nextStreak = (streak: number, best: number, won: boolean) => {
      const newStreak = won ? streak + 1 : 0;
      return { win_streak: newStreak, best_streak: Math.max(newStreak, best) };
    };

    await admin.from("rankings").update({
      elo_rating: newChallengerElo,
      wins: challengerRanking.wins + (challengerWon ? 1 : 0),
      losses: challengerRanking.losses + (opponentWon ? 1 : 0),
      ...nextStreak(challengerRanking.win_streak, challengerRanking.best_streak, challengerWon),
    }).eq("user_id", duel.challenger_id);

    await admin.from("rankings").update({
      elo_rating: newOpponentElo,
      wins: opponentRanking.wins + (opponentWon ? 1 : 0),
      losses: opponentRanking.losses + (challengerWon ? 1 : 0),
      ...nextStreak(opponentRanking.win_streak, opponentRanking.best_streak, opponentWon),
    }).eq("user_id", duel.opponent_id);
  }

  return new Response(JSON.stringify({ duel: updatedDuel }), { headers: jsonHeaders });
});
