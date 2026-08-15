# Iron Line

Camera-tracked competitive gym app. Real workouts become the game.

Full product/technical spec: [`docs/framework.md`](docs/framework.md).
API contract (direct Supabase client vs. Edge Functions): [`docs/api-contracts.md`](docs/api-contracts.md).

## Repo layout

```
IronLine/        iOS app (Swift/SwiftUI) — MyGayLoverAtlas
supabase/        Backend: migrations, Edge Functions, seed data — Johnathon
docs/            Framework spec + API contracts, shared reference
```

## Team

| Area | Owner |
|---|---|
| Backend (Supabase, DB, API, logic) | Johnathon |
| Frontend (Swift/SwiftUI, camera, UI/UX) | MyGayLoverAtlas |

## Setup

### Backend (Johnathon)

1. Install the Supabase CLI (`brew install supabase/tap/supabase`) if you haven't.
2. Create a project at [supabase.com](https://supabase.com).
3. `supabase login`, then from this repo: `supabase link --project-ref <your-project-ref>`.
4. Push the migrations: `supabase db push` (applies `supabase/migrations/001_users.sql` and `002_exercises.sql`, then seed with `supabase/seed/exercises.sql`).
5. Email/password auth is on by default. Apple Sign-In is deferred — not needed until closer to alpha (see §12 note below).
6. Send MyGayLoverAtlas the project URL and **anon** key only — never the service role key.

### Frontend (MyGayLoverAtlas)

1. Open the `IronLine/` folder in Xcode as a new project (create the `.xcodeproj` around these files).
2. Add `supabase-swift` via Swift Package Manager.
3. Copy `IronLine/Resources/Secrets.plist.example` to `IronLine/Resources/Secrets.plist` and fill in the URL/anon key Johnathon sends you. `Secrets.plist` is gitignored — never commit it.
4. Build out `LoginView`, `ProfileSetupView`, `HomeView`.

## Git workflow

One Supabase project (dev = prod) until closer to alpha — not worth the overhead of a separate staging project yet. Work in feature branches off `main`, PR when a phase task is ready to merge. Branch naming: `phase0-<short-desc>`, `phase1-<short-desc>`, etc.

## Deferred

- **Apple Sign-In**: needs a paid Apple Developer Program membership. Not required for Phase 0/1 — email/password covers auth until then. It'll be needed anyway before TestFlight (Phase 5), so revisit around then.

## Phase plan

See [`docs/framework.md`](docs/framework.md) §8 for the full phased build plan (Phase 0 → Phase 5).
