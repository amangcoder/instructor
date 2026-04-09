#!/usr/bin/env bash
# migrate.sh — Run Drizzle-kit migrations against Neon PostgreSQL
#
# IMPORTANT: Migrations MUST use the DIRECT connection string (no -pooler suffix).
# drizzle-kit uses session-level features (SET search_path, advisory locks) that
# Neon's PgBouncer transaction mode does NOT support. Using the pooler URL will
# fail with: "prepared statement does not exist" or SET command errors.
#
# Usage:
#   ./scripts/migrate.sh            # uses DATABASE_URL_DIRECT from .env
#   DATABASE_URL_DIRECT="..." ./scripts/migrate.sh   # pass inline
#
# After running, update DATABASE_URL in .env to the pooler connection string
# before starting the application server.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$SERVER_DIR"

# Load .env if present (for local dev)
if [ -f ".env" ]; then
  # shellcheck disable=SC1091
  set -o allexport
  source .env
  set +o allexport
fi

# Validate that DATABASE_URL_DIRECT is set
if [ -z "${DATABASE_URL_DIRECT:-}" ]; then
  echo "ERROR: DATABASE_URL_DIRECT is not set." >&2
  echo "" >&2
  echo "Set it in .env or pass it inline:" >&2
  echo "  DATABASE_URL_DIRECT='postgres://user:pass@ep-<name>.<region>.aws.neon.tech/neondb?sslmode=require' \\" >&2
  echo "  ./scripts/migrate.sh" >&2
  echo "" >&2
  echo "The DIRECT connection string (no -pooler suffix) is required for migrations." >&2
  echo "Find it in: Neon dashboard → Connection Details → Direct connection" >&2
  exit 1
fi

# Warn if someone accidentally passes a pooler URL
if echo "$DATABASE_URL_DIRECT" | grep -q "\-pooler\."; then
  echo "WARNING: DATABASE_URL_DIRECT appears to contain a pooler endpoint (-pooler suffix)." >&2
  echo "Migrations require the DIRECT connection string (no -pooler suffix)." >&2
  echo "Pooler URL detected: $DATABASE_URL_DIRECT" >&2
  echo "" >&2
  read -r -p "Continue anyway? [y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "Aborted." >&2
    exit 1
  fi
fi

echo "Running drizzle-kit migrate with DIRECT connection..."
echo "Host: $(echo "$DATABASE_URL_DIRECT" | sed 's|postgres://[^@]*@||' | cut -d'/' -f1)"
echo ""

# Run migrations using the direct connection string
DATABASE_URL="$DATABASE_URL_DIRECT" npx drizzle-kit migrate

echo ""
echo "Migrations applied successfully."
echo ""
echo "Next steps:"
echo "  1. Verify schema: psql \"\$DATABASE_URL_DIRECT\" -f scripts/verify-schema.sql"
echo "  2. Ensure DATABASE_URL in .env is set to the POOLER connection string for runtime."
