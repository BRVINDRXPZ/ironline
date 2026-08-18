#!/bin/bash
# Free-tier Supabase has no automatic point-in-time recovery, so this takes
# its place: a nightly schema+data dump, kept locally with a 14-day rotation.
#
# Uses native pg_dump (not `supabase db dump`, which requires Docker) against
# a connection string read from a local file — see README.md for setup.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DB_URL_FILE="$SCRIPT_DIR/.db-url"
BACKUP_DIR="$HOME/ironline-backups"
STAMP=$(date +%Y-%m-%d_%H%M%S)
RETENTION_DAYS=14
PG_DUMP="/opt/homebrew/opt/libpq/bin/pg_dump"

if [ ! -f "$DB_URL_FILE" ]; then
  echo "$(date): missing $DB_URL_FILE — see ops/backups/README.md" >> "$BACKUP_DIR/backup.log"
  exit 1
fi

mkdir -p "$BACKUP_DIR"

"$PG_DUMP" "$(cat "$DB_URL_FILE")" -f "$BACKUP_DIR/ironline_$STAMP.sql" >> "$BACKUP_DIR/backup.log" 2>&1

find "$BACKUP_DIR" -name "ironline_*.sql" -mtime "+$RETENTION_DAYS" -delete
