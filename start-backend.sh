#!/usr/bin/env bash
# Start all backend servers for local development.
#
# Services:
#   • Kokoro TTS (FastAPI)  — port 3070
#   • NestJS API            — port 3071
#
# Usage:
#   ./start-backend.sh          # Start both servers
#   ./start-backend.sh server   # Start NestJS only
#   ./start-backend.sh kokoro   # Start Kokoro only

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

cleanup() {
  echo ""
  echo "Shutting down..."
  kill 0 2>/dev/null
  wait 2>/dev/null
}
trap cleanup EXIT INT TERM

start_kokoro() {
  echo "Starting Kokoro TTS server on port 3070..."
  cd "$ROOT_DIR/kokoro-server"
  uvicorn main:app --host 127.0.0.1 --port 3070 --reload &
}

start_server() {
  echo "Starting NestJS API server on port 3071..."
  cd "$ROOT_DIR/server"
  npm run start:dev &
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
