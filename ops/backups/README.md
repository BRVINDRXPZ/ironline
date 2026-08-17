# Database backups (free-tier workaround)

Supabase's free tier doesn't include point-in-time recovery, so this
replaces it: a nightly `pg_dump` of the whole database, kept locally with a
14-day rotation. Runs at 3am daily via a LaunchAgent.

## One-time setup

1. Supabase Dashboard → your project → **Project Settings** → **Database** →
   **Connection string** → **URI** tab. Copy it (it includes your DB
   password — this is far more sensitive than the anon key, since it's raw
   Postgres access that bypasses RLS entirely). Use the **direct connection**
   string, not the pooled/transaction one.
2. Save it to a local file — run this yourself, don't paste the URL into
   chat with an AI assistant:
   ```bash
   echo 'postgresql://postgres:[YOUR-PASSWORD]@[HOST]:5432/postgres' > ops/backups/.db-url
   chmod 600 ops/backups/.db-url
   ```
3. Test it manually: `./ops/backups/backup.sh`, then check
   `~/ironline-backups/` for a non-empty `.sql` file.
4. Install the schedule:
   ```bash
   cp ops/backups/com.ironline.backup.plist ~/Library/LaunchAgents/
   launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.ironline.backup.plist
   ```

## Notes

- Backups live in `~/ironline-backups/`, outside the repo — never committed.
- 14-day local retention only. This machine is a single point of failure;
  if you want off-machine redundancy, point `BACKUP_DIR` in `backup.sh` at
  an iCloud Drive or Dropbox-synced folder instead.
- To restore: `psql "$(cat ops/backups/.db-url)" -f ~/ironline-backups/ironline_<timestamp>.sql`
  — do this against a *new* project first to verify, never directly against
  production without a plan.
- Check `~/ironline-backups/backup.log` if a night's backup looks off.
