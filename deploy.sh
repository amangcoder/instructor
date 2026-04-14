#!/usr/bin/env bash
# deploy.sh — Deploy Instructor infrastructure to AWS (production)
#
# Usage:
#   ./deploy.sh
#
# Prerequisites:
#   1. AWS CLI configured with credentials that have CDK deploy permissions:
#        aws configure   (or set AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / AWS_DEFAULT_REGION)
#   2. CDK bootstrapped in the target account/region (first time only):
#        cd infra && npx cdk bootstrap
#   3. All secrets populated in Secrets Manager (see server/README.md for full checklist)
#      NEW: ADMIN_API_KEY must be added to instructor/prod/app-secrets
#   4. Node.js >= 18 and npm installed
#   5. DATABASE_URL_DIRECT set in server/.env (direct Neon connection, no -pooler suffix)
#      Required for database migrations — see server/.env.example for format
#
# What this script does:
#   1. Build server (esbuild bundle)
#   2. Ensure infra dependencies + TypeScript build
#   3. Run database migrations (drizzle-kit migrate — MUST precede Lambda deploy)
#   4. CDK deploy for ALL stacks
#   5. Seed library plans (idempotent)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/infra"
SERVER_DIR="${SCRIPT_DIR}/server"

echo "==> Instructor Production Deploy"
echo "    Infra directory : ${INFRA_DIR}"
echo "    SES from email  : instructor.app@layersiq.com"
echo "    Env             : prod"
echo ""

# ── 1. Build server (esbuild bundle) — MUST run before CDK deploy ────────────
# The Lambda handler is dist/lambda.js (esbuild self-contained bundle).
# Running 'nest start' or 'tsc' also writes dist/lambda.js but as a thin
# TypeScript-compiled file that requires external modules → Lambda fails.
# Always regenerate the esbuild bundle here so CDK packages the correct file.
echo "==> Building server (esbuild bundle)..."
(cd "${SERVER_DIR}" && pnpm run build)

# ── 2. Ensure infra dependencies are installed ───────────────────────────────
if [ ! -d "${INFRA_DIR}/node_modules" ]; then
  echo "==> Installing infra dependencies..."
  (cd "${INFRA_DIR}" && npm install)
fi

# ── 3. Build TypeScript (CDK needs compiled JS) ───────────────────────────────
echo "==> Building CDK TypeScript..."
(cd "${INFRA_DIR}" && npm run build)

# ── 4. Database migrations — MUST run before Lambda deploy ───────────────────
# Applies schema changes: library_plans, tts_jobs, new plans columns, drops sync_metadata.
# Uses DATABASE_URL_DIRECT (no -pooler suffix) as required by drizzle-kit.
# Migrations are idempotent — safe to re-run on an already-deployed schema.
echo "==> Running database migrations..."
(cd "${SERVER_DIR}" && pnpm run db:migrate)

echo "==> Verifying schema..."
(cd "${SERVER_DIR}" && pnpm run db:verify) || echo "    ⚠  Schema verify failed — check output above before proceeding"

# ── 5. CDK Deploy ─────────────────────────────────────────────────────────────
echo "==> Running CDK deploy..."
cd "${INFRA_DIR}" && npx cdk deploy \
  --all \
  --context env=prod \
  --context sesFromEmail=instructor.app@layersiq.com \
  --require-approval broadening

# ── 6. Seed library plans ─────────────────────────────────────────────────────
# Populates library_plans with the 5 starter plans (idempotent — skips existing).
echo ""
echo "==> Seeding library plans..."
(cd "${SERVER_DIR}" && pnpm run seed:library-plans) || echo "    ⚠  Seed failed — run manually: cd server && pnpm run seed:library-plans"

echo ""
echo "==> Deploy complete."
echo "    Check CloudFormation outputs above for:"
echo "      • ApiUrl          — set as BACKEND_URL in the Flutter app"
echo "      • LambdaFunctionName"
echo "      • AppSecretsArn"
echo "      • AlarmTopicArn   — subscribe your ops email to receive CloudWatch alerts"
echo ""
echo "    Post-deploy verification:"
echo "      # Health check"
echo "      curl <ApiUrl>/api/health"
echo "      # Library plans (should return 5 seeded plans)"
echo "      curl <ApiUrl>/api/library/plans"
