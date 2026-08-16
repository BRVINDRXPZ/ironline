# API Contract — Direct Client vs. Edge Functions

Per framework spec §9. This is the line both of you build against.

## Direct Supabase client (`supabase-swift`)

Reads and simple single-table writes. No business logic.

| Operation | Table |
|---|---|
| Sign up / sign in / sign out | `auth` |
| Read / update own profile | `users` |
| List active exercises | `exercises` |
| Create / complete a workout session | `workout_sessions` |
| Read own set/session history (raw) | `workout_sessions`, `sets` |
| Read own LINE history (for the history chart) | `the_line` |
| Read friends / crew membership | `friendships`, `crews`, `crew_members` |

RLS on each table enforces `auth.uid()` scoping — the client never needs to filter by user id manually, but should anyway for clarity.

**Authority rule:** clients never write `the_line`, duel outcomes, rankings/ELO, or other competitive state directly. Those values must be produced by trusted server logic from verified inputs.

## Edge Functions (`supabase/functions/`)

Anything with cross-table logic, external calls, or rules that shouldn't ship in the app binary.

| Function | Triggers | Does |
|---|---|---|
| `save-set` | client submits a completed verified set | inserts into `sets`, checks prior sets for that exercise, flags `is_pr` |
| `get-history` | client requests set history for an exercise | returns the caller's sets for that `exercise_id`, most recent first |
| `calculate-line` | after a session completes for an exercise | Epley e1RM, recency weighting, writes a new authoritative `the_line` version (or baseline countdown if <3 sessions) |
| `get-line` | client wants the active LINE for an exercise | returns the highest-version `the_line` row, or `{ baseline: true, sessions_remaining }` if none exists |
| `line-score` | client wants a set scored against the LINE | `(actual_e1RM - predicted_e1RM) / predicted_e1RM x 100` for a given `set_id` |
| `resolve-duel` | opponent submits their set | compares `line_score`s, sets `winner_id`, calls `update-elo` |
| `update-elo` | called by `resolve-duel` | standard ELO (K=32), updates `rankings` for both players |
| `check-duel-expiry` | cron, every 15 min | marks duels past `expires_at` as `expired`, no ELO change |
| `get-ghost` | client requests ghost for an exercise | returns best recent set to beat from `ghost_records` |
| `generate-trash-talk` | during active duel rest periods | calls Claude API with duel context, writes `trash_talk_log` |

Each function expects the caller's Supabase JWT in the `Authorization` header and derives `auth.uid()` server-side — never trust a user id passed in the request body.

Functions that need to write authoritative competitive state may use the service-role client **only after authenticating the caller**, and the user id written to the database must come from that verified JWT. Service-role credentials never ship in the iOS app.

## Swift invocation convention

- POST/body functions use `APIService.invoke(_:body:)`.
- GET/query functions such as `get-line` use `APIService.invokeGET(_:query:)`.

## Adding a new Edge Function

1. `supabase functions new <name>`
2. Import shared CORS/auth helpers from `supabase/functions/_shared/`
3. Test locally: `supabase functions serve <name>`
4. Deploy: `supabase functions deploy <name>`
