# IRON LINE — Development Framework & Build Spec

> **Working Title:** Iron Line
> **Core Thesis:** Don't gamify workout logging — turn real physical performance into a verified competitive game.

---

## 1. Product Overview

A camera-tracked competitive gym app where real workouts become the game. The phone camera acts as referee — recognizing exercises, counting reps, and validating range of motion. An AI-calculated performance baseline ("THE LINE") creates personalized targets, and players compete against themselves, their friends, and their crews through async duels, ghost races, and ranked challenges.

### V1 Alpha Scope

- **Platform:** iOS only (Swift/SwiftUI)
- **Distribution:** Closed alpha via TestFlight, invite-only
- **Camera Engine:** Apple Vision Framework (on-device pose estimation)
- **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
- **Auth:** Apple Sign-In + Email/Password
- **Game Modes:** Duels (async), Beat Your Ghost (numeric), THE LINE
- **Social:** Invite friends, crews (cap: 5)
- **Aesthetic:** Dark, premium, data-dense — WHOOP × UFC × Gran Turismo

### Cut from V1 (Revisit in V2+)

- Live spectating
- Global leaderboard
- Camera-based weight recognition
- Proof clips / verification
- Android support
- Beat the Clip mode
- Survival mode, Boss challenges
- King of the Gym titles
- Weekly challenges

---

## 2. Tech Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Swift / SwiftUI | Native iOS, best camera performance |
| Camera / CV | Apple Vision Framework | On-device pose estimation, skeleton tracking |
| Backend | Supabase | PostgreSQL, Auth, Realtime subscriptions, Storage |
| Auth | Supabase Auth | Apple Sign-In + email/password |
| Realtime | Supabase Realtime | Duel updates, notifications, crew activity |
| AI / Trash Talk | Claude API or similar | AI-generated trash talk during rest periods |
| Audio | AVSpeechSynthesizer or pre-recorded | Coach voice for rep counts, feedback |
| Distribution | TestFlight | Closed alpha |

---

## 3. Team Roles

| Area | Owner | Notes |
|---|---|---|
| Backend (Supabase, DB, API, logic) | **Johnathon** | Database schema, RLS policies, Edge Functions, THE LINE algorithm, ELO system, duel logic |
| Frontend (Swift/SwiftUI, UI/UX) | **MyGayLoverAtlas** | All screens, navigation, animations, camera integration, Apple Vision, audio feedback |
| Shared | Both | Architecture decisions, exercise recognition logic, testing, QA |

> **Note:** The camera/pose-estimation work is frontend (runs on-device in Swift), but the exercise recognition LOGIC (what joint angles = a bench press rep) will be co-developed. Johnathon defines the rules, MyGayLoverAtlas implements them in the Vision pipeline.

---

## 4. V1 Exercise List

One exercise per major muscle group. Camera must recognize and count reps with binary ROM validation (full rep or no-rep).

| Muscle Group | Exercise | Key Joints to Track | ROM Signal |
|---|---|---|---|
| Chest | Bench Press | Shoulders, elbows, wrists | Elbows break 90° → full extension |
| Back | Barbell Row | Hips, shoulders, elbows | Bar to torso → full arm extension |
| Shoulders | Overhead Press | Shoulders, elbows, wrists | Bar at shoulders → full lockout overhead |
| Quads | Barbell Squat | Hips, knees, ankles | Hip crease below knee → full standing |
| Hams/Glutes | Deadlift | Hips, knees, shoulders | Bar on floor → full hip extension/lockout |
| Biceps | Barbell Curl | Elbows, wrists, shoulders | Full arm extension → full contraction |
| Triceps | Skull Crushers | Elbows, wrists, shoulders | Full extension → elbows at ~90° → full extension |
| Core | Hanging Leg Raises | Hips, knees, shoulders | Legs hanging → legs at/above 90° hip flexion |

---

## 5. Database Schema (Supabase/PostgreSQL)

### Core Tables

```
users
├── id (uuid, PK)
├── email
├── apple_id
├── display_name
├── avatar_url
├── height_inches (int)
├── weight_lbs (decimal)
├── age (int)
├── gender (text) -- male/female/other
├── training_experience (text) -- beginner/intermediate/advanced
├── training_goal (text) -- strength/hypertrophy/general
├── preferred_units (text) -- lbs/kg
├── created_at
└── updated_at

friendships
├── id (uuid, PK)
├── user_id (FK → users)
├── friend_id (FK → users)
├── status (text) -- pending/accepted/declined
├── created_at
└── updated_at

crews
├── id (uuid, PK)
├── name (text)
├── created_by (FK → users)
├── created_at
└── max_members (int, default 5)

crew_members
├── crew_id (FK → crews)
├── user_id (FK → users)
├── joined_at
└── role (text) -- leader/member

exercises
├── id (uuid, PK)
├── name (text)
├── muscle_group (text)
├── joint_config (jsonb) -- which joints to track, ROM thresholds
└── is_active (bool)

workout_sessions
├── id (uuid, PK)
├── user_id (FK → users)
├── started_at
├── ended_at
└── status (text) -- in_progress/completed/abandoned

sets
├── id (uuid, PK)
├── session_id (FK → workout_sessions)
├── exercise_id (FK → exercises)
├── set_number (int)
├── weight (decimal) -- manually entered
├── reps_completed (int) -- camera-verified
├── reps_attempted (int) -- includes no-reps
├── rom_pass_rate (decimal) -- % of reps with full ROM
├── started_at
├── ended_at
└── is_pr (bool)

the_line
├── id (uuid, PK)
├── user_id (FK → users)
├── exercise_id (FK → exercises)
├── predicted_weight (decimal)
├── predicted_reps (int)
├── confidence (decimal) -- how much data backs this
├── baseline_sessions (int) -- sessions used to calculate
├── calculated_at
└── version (int) -- recalculates over time

duels
├── id (uuid, PK)
├── challenger_id (FK → users)
├── opponent_id (FK → users)
├── exercise_id (FK → exercises)
├── status (text) -- pending/accepted/declined/in_progress/completed/expired
├── challenger_set_id (FK → sets, nullable)
├── opponent_set_id (FK → sets, nullable)
├── challenger_line_score (decimal) -- % above/below their LINE
├── opponent_line_score (decimal)
├── winner_id (FK → users, nullable)
├── created_at
├── expires_at (timestamp) -- created_at + 48hrs
└── updated_at

rankings
├── id (uuid, PK)
├── user_id (FK → users)
├── elo_rating (int, default 1200)
├── wins (int)
├── losses (int)
├── win_streak (int)
├── best_streak (int)
└── updated_at

ghost_records
├── id (uuid, PK)
├── user_id (FK → users)
├── exercise_id (FK → exercises)
├── set_id (FK → sets) -- the set to beat
├── weight (decimal)
├── reps (int)
├── beaten (bool, default false)
├── beaten_by_set_id (FK → sets, nullable)
└── created_at

trash_talk_log
├── id (uuid, PK)
├── duel_id (FK → duels)
├── sender_type (text) -- ai/system
├── message (text)
├── context (text) -- rest_period/duel_result/callout
├── created_at
└── seen (bool)
```

---

## 6. THE LINE — Algorithm Spec

### Purpose
Calculate a personalized, per-exercise performance prediction that the user tries to beat. It adapts over time based on training history.

### Inputs
- All historical sets for the given exercise (weight × reps)
- User profile (bodyweight, training age, gender, goal)
- Recency weighting (recent sessions matter more)
- Recovery signals if available (days since last session for this exercise)

### First-Session Behavior
- No LINE displayed for the first 3 sessions per exercise
- During baseline period, app shows "Building your LINE... (2 sessions remaining)"
- After 3 sessions: LINE activates at a level slightly below their average performance
- Goal: user beats it on first real attempt, feels good, comes back

### Calculation (V1 — Simple)
```
For a given exercise:
1. Collect last N sets (N = all available, max 30)
2. Calculate estimated 1RM for each set using Epley: weight × (1 + reps/30)
3. Apply recency weighting (exponential decay, half-life = 14 days)
4. THE LINE = weighted average e1RM × 0.92 (slightly below average)
5. Convert back to weight × reps target using user's typical rep range
6. Confidence score = min(sessions_count / 10, 1.0)
```

### LINE Score (for duels & rankings)
```
line_score = (actual_e1RM - predicted_e1RM) / predicted_e1RM × 100
```
Positive = beat THE LINE. Negative = missed it. Duel winner = higher line_score.

### Adaptation
- THE LINE recalculates after every completed session for that exercise
- If user beats LINE 3x in a row → LINE adjusts upward faster
- If user misses LINE 3x in a row → LINE adjusts downward (but slowly, to encourage pushing)

---

## 7. ELO Ranking System

### Starting Rating
All users start at 1200 ELO.

### Calculation
Standard ELO with K-factor of 32 (higher volatility for a game context):
```
Expected score: E_a = 1 / (1 + 10^((R_b - R_a) / 400))
New rating: R_a' = R_a + K × (S_a - E_a)
where S_a = 1 (win), 0 (loss), 0.5 (draw — both beat or both miss LINE by same margin)
```

### Rules
- ELO only changes on completed duels
- Declining a duel = no ELO change
- Expired duels (48hr) = no ELO change
- ELO is global across all exercises (single rating per user)

---

## 8. Phased Build Plan

Each phase produces a working, testable increment. Phases are designed to be tackled as time allows — no hard deadlines, just logical sequence.

---

### PHASE 0: Environment & Foundation
**Goal:** Both devs set up, can build and run an empty app, backend is provisioned.

#### Johnathon (Backend)
- [ ] Create Supabase project
- [ ] Configure auth providers (Apple Sign-In, email/password)
- [ ] Set up development and staging environments
- [ ] Create initial database migration with users table
- [ ] Set up Row Level Security (RLS) policies for users
- [ ] Create Edge Function boilerplate (for future API logic)
- [ ] Set up Supabase CLI for local development
- [ ] Document API patterns and conventions for MyGayLoverAtlas

#### MyGayLoverAtlas (Frontend)
- [ ] Install Xcode, set up iOS development environment
- [ ] Create Swift/SwiftUI project with proper structure
- [ ] Set up Supabase Swift SDK (supabase-swift)
- [ ] Create basic app shell with tab navigation
- [ ] Implement Apple Sign-In flow → Supabase auth
- [ ] Implement email/password sign-up/login → Supabase auth
- [ ] Build profile creation screen (height, weight, age, gender, experience, goal, units)
- [ ] Connect profile to Supabase users table
- [ ] Set up TestFlight for alpha distribution

#### Shared
- [ ] Agree on project structure, naming conventions, Git workflow
- [ ] Set up shared GitHub repo with branch strategy
- [ ] Define API contract: how frontend calls backend (direct Supabase client vs Edge Functions)

**Deliverable:** App launches, user can sign up, create profile, see empty home screen.

---

### PHASE 1: Camera & Exercise Recognition Engine
**Goal:** Phone camera can detect a person, identify an exercise, and count reps with ROM validation.

#### Johnathon (Backend)
- [ ] Create exercises table with joint configuration data (seed all 8 V1 exercises)
- [ ] Define exercise recognition rules as structured data:
  - Which joints define each exercise
  - What movement pattern (joint angle changes over time) = one rep
  - ROM thresholds for full rep vs. no-rep (binary)
  - Expected camera angle (side view from floor level)
- [ ] Create workout_sessions and sets tables with migrations
- [ ] Build Edge Function: save completed set → database
- [ ] Build Edge Function: get user's exercise history
- [ ] Set up RLS policies for workout data

#### MyGayLoverAtlas (Frontend)
- [ ] Integrate Apple Vision Framework for body pose detection
- [ ] Build camera view (full screen, phone propped on floor orientation)
- [ ] Render skeleton overlay on detected body in real-time
- [ ] Implement "closest person to camera" selection logic
- [ ] Build exercise recognition engine:
  - Parse joint positions from Vision framework
  - Calculate joint angles in real-time
  - Match movement patterns to exercise definitions from backend
  - Display detected exercise name on screen
- [ ] Build rep counter:
  - Track joint angle state machine (bottom position → top position = 1 rep)
  - Apply ROM threshold (binary: count or no-count)
  - Display rep count on screen with visual feedback
- [ ] Handle tracking loss: pause counter, show "tracking lost" indicator, resume when recovered
- [ ] Build manual weight entry UI (shown before or after set)
- [ ] Build workout session flow: start workout → select exercise → record sets → end workout

#### Shared
- [ ] Test exercise recognition with real gym footage for each of the 8 exercises
- [ ] Tune joint angle thresholds iteratively (this WILL require multiple rounds)
- [ ] Document which camera positions/angles work best per exercise

**Deliverable:** User can start a workout, prop phone on floor, perform an exercise, and see accurate rep counts with ROM validation. Sets are saved to database.

---

### PHASE 2: THE LINE
**Goal:** After 3 sessions per exercise, THE LINE appears and the user can try to beat it.

#### Johnathon (Backend)
- [ ] Create the_line table with migrations
- [ ] Build THE LINE calculation Edge Function:
  - Fetch user's set history for given exercise
  - Calculate estimated 1RM per set (Epley formula)
  - Apply recency weighting
  - Output predicted weight × reps target
  - Store with confidence score and version
- [ ] Build "should LINE activate?" check (≥3 sessions for exercise)
- [ ] Build LINE recalculation trigger (runs after each completed session)
- [ ] Build LINE adaptation logic (3x beat → faster increase, 3x miss → slow decrease)
- [ ] Build Edge Function: get current LINE for user × exercise
- [ ] Build Edge Function: calculate line_score after a set (actual vs predicted)

#### MyGayLoverAtlas (Frontend)
- [ ] Build LINE display on workout screen:
  - Before set: "THE LINE: 185 lbs × 8 reps" target display
  - During set: real-time progress indicator (reps counting toward target)
  - After set: dramatic BEAT / MISSED result animation
- [ ] Build baseline period indicator: "Building your LINE... (X sessions remaining)"
- [ ] Build LINE history view (how THE LINE has moved over time — simple chart)
- [ ] Integrate coach voice audio feedback:
  - Rep count voice ("one... two... three...")
  - ROM feedback ("good rep" / "no rep")
  - LINE result ("LINE beaten!" / "missed it")
- [ ] Add rest timer between sets with stats display

**Deliverable:** User works out for 3 sessions, LINE appears, they can try to beat it with dramatic feedback. Coach voice counts reps.

---

### PHASE 3: Social Layer
**Goal:** Users can add friends, create crews, and see each other's activity.

#### Johnathon (Backend)
- [ ] Create friendships table with migrations and RLS
- [ ] Build friend request system (send, accept, decline)
- [ ] Create invite code system (unique codes to share with friends)
- [ ] Create crews and crew_members tables with migrations and RLS
- [ ] Build crew CRUD (create, join via invite, leave, disband)
- [ ] Enforce crew cap (5 members)
- [ ] Build Edge Function: get friend's recent activity (workout summaries, PRs)
- [ ] Build Edge Function: get crew leaderboard (ranked by recent LINE performance)
- [ ] Set up Supabase Realtime channels for crew activity updates
- [ ] Build push notification infrastructure (APNs via Supabase or external service)

#### MyGayLoverAtlas (Frontend)
- [ ] Build friends list screen (list, add friend, pending requests)
- [ ] Build invite code sharing (generate, copy, share sheet)
- [ ] Build crew screen (members, crew name, simple leaderboard)
- [ ] Build crew creation / join flow
- [ ] Build activity feed (friend's recent sets, PRs, LINE beats)
- [ ] Build push notification handling (friend requests, crew invites)
- [ ] Build PR celebration screen (dramatic animation when user hits a personal record)

**Deliverable:** Users can add friends via invite codes, create crews of 5, and see each other's workout activity and PRs.

---

### PHASE 4: Duels & Beat Your Ghost
**Goal:** Async duels between friends with ELO ranking, and Beat Your Ghost mode.

#### Johnathon (Backend)
- [ ] Create duels table with migrations and RLS
- [ ] Build duel flow Edge Functions:
  - Create duel (challenger picks exercise, system records their set)
  - Accept/decline duel
  - Submit opponent's set
  - Calculate winner (compare line_scores)
  - Handle expiration (48hr cron job or database trigger)
- [ ] Create rankings table with migrations
- [ ] Build ELO calculation Edge Function (update both players after duel completes)
- [ ] Create ghost_records table with migrations
- [ ] Build ghost system:
  - After each set, store as ghost record for that exercise
  - Get user's ghost for a given exercise (their best recent set to beat)
  - Mark ghost as beaten when surpassed
- [ ] Build AI trash talk Edge Function:
  - Call Claude API (or similar) with duel context
  - Generate contextual trash talk based on: who's winning, by how much, exercise, history
  - Store in trash_talk_log
  - Trigger during rest periods of active duels
- [ ] Set up Supabase Realtime for duel status updates

#### MyGayLoverAtlas (Frontend)
- [ ] Build duel challenge flow:
  - Select friend → select exercise → perform set → send challenge
  - Receive challenge notification → accept → perform set → see result
- [ ] Build duel results screen:
  - Side-by-side comparison (your set vs opponent)
  - LINE scores for each
  - Winner announcement with animation
  - ELO change display (+15 / -15)
- [ ] Build active duels list (pending, in-progress, completed)
- [ ] Build duel history (W/L record, ELO chart over time)
- [ ] Build Beat Your Ghost mode:
  - Before set: "Your ghost: 185 × 8 — beat it"
  - After set: "Ghost beaten!" or "Ghost survives"
  - Ghost history per exercise
- [ ] Build rest timer integration:
  - Show AI trash talk messages during rest (with animation)
  - Show duel status updates
  - Show current stats (today's volume, PRs, LINE status)
- [ ] Build rankings screen (ELO leaderboard within friends/crew)

**Deliverable:** Users can send async duels, compete on LINE score, see ELO rankings, get AI trash talk, and race their own ghost records.

---

### PHASE 5: Polish & Alpha Launch
**Goal:** Premium aesthetic, bug fixes, performance optimization, alpha-ready.

#### Johnathon (Backend)
- [ ] Performance audit: optimize database queries, add indexes
- [ ] Set up database backups
- [ ] Add error logging and monitoring (Supabase built-in + any additional)
- [ ] Stress test Realtime channels
- [ ] Security audit: review all RLS policies, Edge Function auth
- [ ] Seed test data for QA
- [ ] Write API documentation for future reference

#### MyGayLoverAtlas (Frontend)
- [ ] Implement premium dark aesthetic across all screens:
  - Dark backgrounds, high-contrast data displays
  - Accent colors (consider: electric blue, red for intensity, gold for PRs)
  - Data-dense dashboard home screen
  - Gran Turismo-style stat presentations
  - UFC-style dramatic result reveals
- [ ] Add animations:
  - LINE beat/miss dramatic reveal
  - PR celebration
  - Duel result
  - ELO change
  - Rep count feedback
- [ ] Haptic feedback on key moments (rep counted, LINE beat, duel won)
- [ ] Optimize camera performance (frame rate, battery usage)
- [ ] Build settings screen (edit profile, units, notification preferences)
- [ ] Handle edge cases:
  - Poor lighting in gym
  - Phone orientation changes mid-set
  - App backgrounding during workout
  - Network connectivity loss
- [ ] Full TestFlight build, onboarding flow for alpha testers

#### Shared
- [ ] End-to-end QA: run through every flow at the actual gym
- [ ] Gather alpha tester feedback
- [ ] Prioritize V2 backlog based on alpha learnings

**Deliverable:** Polished alpha on TestFlight, ready for invite-only distribution to gym crew.

---

## 9. Key Architecture Decisions

### On-Device vs. Server Processing
All exercise recognition, rep counting, and ROM validation runs on-device via Apple Vision Framework. The server receives only structured data (exercise ID, rep count, weight, timestamps). No video is uploaded.

### Data Flow Per Set
```
1. User selects exercise, enters weight
2. User props phone, starts set
3. Apple Vision tracks skeleton in real-time (on-device)
4. App logic counts reps, validates ROM (on-device)
5. Set completes → structured data sent to Supabase
6. Server calculates: LINE score, ghost comparison, duel result, ELO update
7. Results pushed back to app via Realtime
```

### Supabase Edge Functions vs. Direct Client
- **Direct client (supabase-swift):** reads, simple inserts (save a set, create a session)
- **Edge Functions:** complex logic (THE LINE calculation, ELO updates, duel resolution, AI trash talk generation) — keeps business logic server-side and out of the app binary

### Camera Positioning
V1 assumes phone propped on floor, roughly 3-6 feet from lifter, side view. Exercise recognition models are trained/tuned for this angle. Future versions can expand to tripod, rack-mounted, or front-facing angles.

---

## 10. File Structure (Proposed)

### iOS Project (MyGayLoverAtlas)
```
IronLine/
├── App/
│   ├── IronLineApp.swift
│   └── AppState.swift
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift
│   │   ├── LoginView.swift
│   │   ├── SignUpView.swift
│   │   └── ProfileSetupView.swift
│   ├── Camera/
│   │   ├── CameraManager.swift
│   │   ├── PoseDetector.swift
│   │   ├── ExerciseRecognizer.swift
│   │   ├── RepCounter.swift
│   │   ├── ROMValidator.swift
│   │   └── CameraOverlayView.swift
│   ├── Audio/
│   │   ├── CoachVoice.swift
│   │   └── HapticManager.swift
│   └── Networking/
│       ├── SupabaseClient.swift
│       └── APIService.swift
├── Features/
│   ├── Home/
│   │   └── HomeView.swift
│   ├── Workout/
│   │   ├── WorkoutSessionView.swift
│   │   ├── SetRecordView.swift
│   │   ├── RestTimerView.swift
│   │   └── WorkoutSummaryView.swift
│   ├── TheLine/
│   │   ├── LineDisplayView.swift
│   │   ├── LineResultView.swift
│   │   └── LineHistoryView.swift
│   ├── Duels/
│   │   ├── DuelChallengeView.swift
│   │   ├── DuelResultView.swift
│   │   ├── ActiveDuelsView.swift
│   │   └── DuelHistoryView.swift
│   ├── Ghost/
│   │   ├── GhostDisplayView.swift
│   │   └── GhostResultView.swift
│   ├── Social/
│   │   ├── FriendsListView.swift
│   │   ├── CrewView.swift
│   │   ├── ActivityFeedView.swift
│   │   └── InviteView.swift
│   ├── Rankings/
│   │   └── RankingsView.swift
│   └── Settings/
│       └── SettingsView.swift
├── Models/
│   ├── User.swift
│   ├── Exercise.swift
│   ├── WorkoutSession.swift
│   ├── Set.swift
│   ├── TheLine.swift
│   ├── Duel.swift
│   ├── Ghost.swift
│   └── Crew.swift
├── Design/
│   ├── Theme.swift
│   ├── Colors.swift
│   ├── Fonts.swift
│   └── Components/
│       ├── StatCard.swift
│       ├── AnimatedResult.swift
│       └── PremiumButton.swift
└── Resources/
    ├── Assets.xcassets
    └── CoachAudio/
```

### Backend (Johnathon)
```
supabase/
├── migrations/
│   ├── 001_users.sql
│   ├── 002_exercises.sql
│   ├── 003_workouts_and_sets.sql
│   ├── 004_the_line.sql
│   ├── 005_friendships.sql
│   ├── 006_crews.sql
│   ├── 007_duels.sql
│   ├── 008_rankings.sql
│   ├── 009_ghost_records.sql
│   └── 010_trash_talk.sql
├── functions/
│   ├── calculate-line/
│   │   └── index.ts
│   ├── resolve-duel/
│   │   └── index.ts
│   ├── update-elo/
│   │   └── index.ts
│   ├── generate-trash-talk/
│   │   └── index.ts
│   ├── check-duel-expiry/
│   │   └── index.ts
│   └── get-ghost/
│       └── index.ts
├── seed/
│   ├── exercises.sql
│   └── test_users.sql
└── config.toml
```

---

## 11. Exercise Recognition Rules — Reference Format

Each exercise definition should be stored as structured JSON in the `exercises.joint_config` column. Example for Bench Press:

```json
{
  "exercise": "Bench Press",
  "camera_angle": "side",
  "primary_joints": ["left_shoulder", "left_elbow", "left_wrist"],
  "body_orientation": "supine",
  "rep_phases": {
    "bottom": {
      "elbow_angle_max": 95,
      "description": "Elbows bent to ~90 degrees, bar near chest"
    },
    "top": {
      "elbow_angle_min": 165,
      "description": "Arms near full extension"
    }
  },
  "rom_threshold": {
    "elbow_angle_at_bottom": 95,
    "rule": "elbow_angle must reach <= threshold to count as full ROM"
  },
  "rep_state_machine": {
    "start": "top",
    "sequence": ["top", "bottom", "top"],
    "completion": "reaching top after valid bottom = 1 rep"
  },
  "noise_filters": {
    "min_rep_duration_ms": 800,
    "max_rep_duration_ms": 8000,
    "joint_confidence_threshold": 0.5
  }
}
```

---

## 12. Claude Code Handoff Notes

When handing phases to Claude Code for implementation:

1. **Work one phase at a time.** Each phase has a clear deliverable — don't skip ahead.
2. **Backend and frontend can be developed in parallel within each phase** — the schema/API contract is defined above.
3. **Phase 1 (Camera Engine) is the highest-risk phase.** Expect iteration. The exercise recognition rules WILL need tuning with real gym footage. Build the system so thresholds are configurable without code changes (pull from database).
4. **Test at the gym, not just at home.** Lighting, angles, clothing, and other people in frame are all real-world variables.
5. **THE LINE algorithm (Phase 2) should be simple in V1.** Don't over-engineer it. The Epley formula + recency weighting + 0.92 multiplier is a solid starting point. It can get smarter later.
6. **Supabase Edge Functions use Deno/TypeScript.** All server-side logic lives there.
7. **The aesthetic (Phase 5) is not an afterthought** — this app lives or dies on feeling premium. But get the mechanics right first, then skin it.

---

*Last updated: August 14, 2026*
*Authors: Johnathon & MyGayLoverAtlas*
