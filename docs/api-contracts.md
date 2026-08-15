# API Contract — Direct Client vs. Edge Functions

Per framework spec §9. This is the line both of you build against.

## Direct Supabase client (`supabase-swift`)

Reads and simple single-table writes. No business logic.

| Operation | Table |
|---|---|
| Sign up / sign in / sign out | `auth` |
| Read / update own profile | `users` |
| List active exercises | `exercises` |
| Create a workout session | `workout_sessions` |
| Insert a completed set | `sets` |
| Read own set/session history | `workout_sessions`, `sets` |
| Read own current LINE | `the_line` |
| Read friends / crew membership | `friendships`, `crews`, `crew_members` |

RLS on each table enforces `auth.uid()` scoping — the client never needs to filter by user id manually, but should anyway for clarity.

## Edge Functions (`supabase/functions/`)

Anything with cross-table logic, external calls, or rules that shouldn't ship in the app binary.

| Function | Triggers | Does |
|---|---|---|
| `calculate-line` | after a session completes for an exercise | Epley e1RM, recency weighting, writes `the_line` row |
| `resolve-duel` | opponent submits their set | compares `line_score`s, sets `winner_id`, calls `update-elo` |
| `update-elo` | called by `resolve-duel` | standard ELO (K=32), updates `rankings` for both players |
| `check-duel-expiry` | cron, every 15 min | marks duels past `expires_at` as `expired`, no ELO change |
| `get-ghost` | client requests ghost for an exercise | returns best recent set to beat from `ghost_records` |
| `generate-trash-talk` | during active duel rest periods | calls Claude API with duel context, writes `trash_talk_log` |

Each function expects the caller's Supabase JWT in the `Authorization` header and uses it to derive `auth.uid()` server-side — never trust a user id passed in the request body.

## Adding a new Edge Function

1. `supabase functions new <name>`
2. Import shared CORS/auth helpers from `supabase/functions/_shared/`
3. Test locally: `supabase functions serve <name>`
4. Deploy: `supabase functions deploy <name>`
