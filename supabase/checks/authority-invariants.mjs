// Static regression guards for the game-integrity findings fixed in
// migrations 015-017.
//
// These are not a substitute for database integration tests — they cannot
// prove the compare-and-swap actually serialises under concurrency, only a
// real Postgres can. What they do is stop the *shape* of each fix from being
// silently undone by a later edit, which is the realistic regression: someone
// adds a convenience UPDATE policy, or drops the status filter "because the
// caller already checked it".
//
// Runs on plain Node (no Deno, no DB, no network) so it can gate every PR.
// Usage: node supabase/checks/authority-invariants.mjs

import { readFileSync, readdirSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const read = (p) => readFileSync(join(root, p), "utf8");
const migrations = readdirSync(join(root, "migrations")).sort();

const failures = [];
const check = (name, condition, detail) => {
  if (!condition) failures.push(`${name}\n    ${detail}`);
};

// ---------------------------------------------------------------- finding 1
// Clients must not be able to author duel outcomes directly.
const duelAuthority = read("migrations/015_duel_authority.sql");

check(
  "015 drops the client UPDATE policy on duels",
  /drop\s+policy\s+if\s+exists\s+"Opponent can respond to and resolve a duel"\s+on\s+public\.duels/i.test(duelAuthority),
  "Without this, an opponent can PATCH /duels and set winner_id themselves.",
);

const reintroducesDuelUpdatePolicy = migrations
  .filter((f) => /^(0(1[5-9]|[2-9]\d)|[1-9]\d{2,})/.test(f))
  .filter((f) => {
    const sql = read(join("migrations", f));
    return /create\s+policy[^;]*on\s+public\.duels\s+for\s+update/is.test(sql);
  });

check(
  "no migration re-grants client UPDATE on duels",
  reintroducesDuelUpdatePolicy.length === 0,
  `Re-granting it reopens finding 1. Offending: ${reintroducesDuelUpdatePolicy.join(", ")}`,
);

// ---------------------------------------------------------------- finding 2
// A duel transitions accepted -> completed exactly once, and ELO moves with it.
const resolveSql = duelAuthority;
const resolveFn = read("functions/resolve-duel/index.ts");

check(
  "resolve_duel reasserts status='accepted' at the authoritative write",
  /update\s+public\.duels[\s\S]*?where[\s\S]*?status\s*=\s*'accepted'/i.test(resolveSql),
  "Checking status before the UPDATE instead of within it allows double resolution.",
);

check(
  "resolve_duel returns null when no row transitions",
  /if\s+v_duel\.id\s+is\s+null\s+then[\s\S]*?return\s+null/i.test(resolveSql),
  "The retry path must apply no ELO and must be distinguishable by the caller.",
);

check(
  "resolve_duel locks both ranking rows in a stable order",
  /order\s+by\s+user_id[\s\S]*?for\s+update/i.test(resolveSql),
  "Unordered locking lets two duels sharing players deadlock.",
);

check(
  "resolve_duel is not callable by anon/authenticated",
  /revoke\s+all\s+on\s+function\s+public\.resolve_duel[\s\S]*?from\s+anon,\s*authenticated/i.test(resolveSql),
  "A SECURITY DEFINER resolver exposed to clients reopens finding 1 through the back door.",
);

check(
  "resolve-duel goes through the RPC",
  /\.rpc\(\s*["']resolve_duel["']/.test(resolveFn),
  "Direct writes from the function cannot be atomic with the ELO update.",
);

check(
  "resolve-duel no longer updates duels directly",
  !/from\(["']duels["']\)[\s\S]{0,200}?\.update\(/.test(resolveFn),
  "Any direct duel UPDATE here bypasses the compare-and-swap.",
);

check(
  "resolve-duel treats a lost compare-and-swap as a conflict",
  /if\s*\(\s*!resolved\s*\)/.test(resolveFn),
  "Ignoring the null return would report a retry as a fresh resolution.",
);

// ---------------------------------------------------------------- finding 6
check(
  "resolve-duel requires the set to postdate the duel",
  /started_at[\s\S]{0,200}?duel\.created_at/.test(resolveFn),
  "Without this an old personal best can win a challenge issued today.",
);

const duelIntegrity = read("migrations/016_duel_integrity.sql");
for (const idx of ["duels_challenger_set_uidx", "duels_opponent_set_uidx"]) {
  check(
    `016 prevents set reuse via ${idx}`,
    new RegExp(`create\\s+unique\\s+index[\\s\\S]*?${idx}`, "i").test(duelIntegrity),
    "A set must not be able to back more than one duel in the same role.",
  );
}

// ---------------------------------------------------------------- finding 5
const createDuel = read("functions/create-duel/index.ts");

check(
  "create-duel requires an accepted friendship",
  /from\(["']friendships["']\)[\s\S]{0,400}?accepted/.test(createDuel),
  "Otherwise any user can challenge any other by raw user id.",
);

check(
  "016 prevents duplicate active challenges",
  /duels_active_matchup_uidx[\s\S]*?status\s+in\s*\(\s*'pending',\s*'accepted'\s*\)/i.test(duelIntegrity),
  "Must be scoped to non-terminal states so rematches still work.",
);

// ---------------------------------------------------------------- finding 4
const redeem = read("functions/redeem-invite/index.ts");

check(
  "redeem-invite claims a use with a compare-and-swap",
  /\.update\(\s*\{\s*use_count:[\s\S]{0,120}?\.eq\(\s*["']use_count["']/.test(redeem),
  "Incrementing without matching the value read allows a lost update.",
);

check(
  "redeem-invite increments exactly once",
  (redeem.match(/use_count:\s*invite\.use_count\s*\+\s*1/g) || []).length === 1,
  "The original trailing unconditional increment must not coexist with the claim.",
);

check(
  "017 backstops the limit at the table",
  /check\s*\(\s*max_uses\s+is\s+null\s+or\s+use_count\s*<=\s*max_uses\s*\)/i.test(
    read("migrations/017_invite_use_count_guard.sql"),
  ),
  "The constraint is what protects against a future writer that forgets the CAS.",
);

// ---------------------------------------------------------------- reporting
if (failures.length > 0) {
  console.error(`\nauthority-invariants: ${failures.length} FAILED\n`);
  for (const f of failures) console.error(`  ✗ ${f}\n`);
  process.exit(1);
}
console.log("authority-invariants: all checks passed");
