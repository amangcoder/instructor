#!/usr/bin/env bash
# Start all backend servers for local development.
#
# Services:
#   • Kokoro TTS (FastAPI)  — port 3070  (English + Hindi voices)
#   • NestJS API            — port 3071  (routes served under /api prefix)
#
# Usage:
#   ./start-backend.sh          # Start both servers
#   ./start-backend.sh server   # Start NestJS only
#   ./start-backend.sh kokoro   # Start Kokoro only

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

CHILD_PIDS=()

cleanup() {
  echo ""
  echo "Shutting down..."
  for pid in "${CHILD_PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  wait 2>/dev/null
}
trap cleanup EXIT INT TERM

start_kokoro() {
  echo "Starting Kokoro TTS server on port 3070..."
  cd "$ROOT_DIR/kokoro-server"
  uvicorn main:app --host 127.0.0.1 --port 3070 --reload &
  CHILD_PIDS+=($!)
}

start_server() {
  echo "Starting NestJS API server on port 3071 (prefix: /api)..."
  cd "$ROOT_DIR/server"
  npm run start:dev &
  CHILD_PIDS+=($!)
}

case "${1:-all}" in
  kokoro)  start_kokoro ;;
  server)  start_server ;;
  all)
    start_kokoro
    start_server
    ;;
  *)
    echo "Usage: $0 [all|server|kokoro]"
    exit 1
    ;;
esac

echo "All servers started. Press Ctrl+C to stop."
wait
