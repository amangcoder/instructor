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
#   4. Node.js >= 18 and npm installed
#
# What this script does:
#   • Installs infra npm dependencies if node_modules is absent
#   • Runs `cdk deploy` for ALL stacks with:
#       --context env=prod
#       --context sesFromEmail=instructor.app@layersiq.com
#       --require-approval broadening   (auto-approve security-broadening IAM changes)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="${SCRIPT_DIR}/infra"

echo "==> Instructor Production Deploy"
echo "    Infra directory : ${INFRA_DIR}"
echo "    SES from email  : instructor.app@layersiq.com"
echo "    Env             : prod"
echo ""

# ── 1. Ensure infra dependencies are installed ───────────────────────────────
if [ ! -d "${INFRA_DIR}/node_modules" ]; then
  echo "==> Installing infra dependencies..."
  (cd "${INFRA_DIR}" && npm install)
fi

# ── 2. Build TypeScript (CDK needs compiled JS) ───────────────────────────────
echo "==> Building CDK TypeScript..."
(cd "${INFRA_DIR}" && npm run build)

# ── 3. CDK Deploy ─────────────────────────────────────────────────────────────
echo "==> Running CDK deploy..."
cd "${INFRA_DIR}" && npx cdk deploy \
  --all \
  --context env=prod \
  --context sesFromEmail=instructor.app@layersiq.com \
  --require-approval broadening

echo ""
echo "==> Deploy complete."
echo "    Check CloudFormation outputs above for:"
echo "      • ApiUrl          — set as BACKEND_URL in the Flutter app"
echo "      • LambdaFunctionName"
echo "      • AppSecretsArn"
echo "      • AlarmTopicArn   — subscribe your ops email to receive CloudWatch alerts"
