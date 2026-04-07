#!/usr/bin/env bash
# Set up and deploy the Kokoro TTS server on Modal.
#
# Usage:
#   ./kokoro-server/setup-modal.sh            # full setup + deploy
#   ./kokoro-server/setup-modal.sh --serve    # full setup + local dev tunnel
#   ./kokoro-server/setup-modal.sh --no-deploy  # setup only (skip deploy)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODAL_APP="$SCRIPT_DIR/modal_app.py"

# ── Colour helpers ─────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD='\033[1m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
else
  BOLD=''; GREEN=''; YELLOW=''; RED=''; NC=''
fi

info()    { echo -e "${GREEN}==>${NC} ${BOLD}$*${NC}"; }
warn()    { echo -e "${YELLOW}[warn]${NC} $*"; }
error()   { echo -e "${RED}[error]${NC} $*" >&2; exit 1; }
substep() { echo -e "    $*"; }

# ── Argument parsing ───────────────────────────────────────────────────────────
MODE="deploy"
for arg in "$@"; do
  case "$arg" in
    --serve)      MODE="serve" ;;
    --no-deploy)  MODE="skip" ;;
    --help|-h)
      echo "Usage: $0 [--serve | --no-deploy]"
      echo ""
      echo "  (default)     Full setup + modal deploy (production)"
      echo "  --serve       Full setup + modal serve (local dev tunnel)"
      echo "  --no-deploy   Install deps and download models, skip deploy"
      exit 0
      ;;
    *) error "Unknown argument: $arg. Run '$0 --help' for usage." ;;
  esac
done

# ── Step 1: Python check ───────────────────────────────────────────────────────
info "Checking Python installation"
if ! command -v python3 &>/dev/null; then
  error "python3 not found. Install Python 3.10+ and re-run."
fi
PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
substep "Python $PY_VERSION found"

# ── Step 2: Install / upgrade Modal ───────────────────────────────────────────
info "Installing Modal client"
if python3 -c "import modal" &>/dev/null 2>&1; then
  substep "Modal already installed — upgrading to latest"
  python3 -m pip install --upgrade modal --quiet
else
  substep "Installing Modal"
  python3 -m pip install modal --quiet
fi

# ── Step 3: Authenticate ───────────────────────────────────────────────────────
info "Checking Modal authentication"
if python3 -c "import modal; modal.config._get_token_id()" &>/dev/null 2>&1; then
  substep "Already authenticated"
else
  substep "Opening browser for authentication…"
  python3 -m modal setup
fi

# ── Step 4: Download model weights into the Modal volume ──────────────────────
info "Downloading Kokoro model weights into Modal volume 'kokoro-models'"
substep "This downloads ~330 MB on first run; subsequent runs skip cached files."
python3 -m modal run "$MODAL_APP::download_models"

# ── Step 5: Deploy or serve ────────────────────────────────────────────────────
case "$MODE" in
  deploy)
    info "Deploying Kokoro TTS server to Modal"
    python3 -m modal deploy "$MODAL_APP"
    echo ""
    echo -e "${GREEN}${BOLD}Deployment complete!${NC}"
    echo ""
    echo "Copy the URL printed above and set it in your NestJS backend .env:"
    echo ""
    echo "    KOKORO_SERVER_URL=https://<workspace>--kokoro-tts-kokoro-server-serve.modal.run"
    echo ""
    ;;
  serve)
    info "Starting Modal dev tunnel (Ctrl+C to stop)"
    python3 -m modal serve "$MODAL_APP"
    ;;
  skip)
    info "Skipping deploy (--no-deploy). Run one of these when ready:"
    echo "    modal deploy kokoro-server/modal_app.py   # production"
    echo "    modal serve  kokoro-server/modal_app.py   # local dev tunnel"
    ;;
esac
