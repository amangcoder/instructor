#!/usr/bin/env bash
set -euo pipefail

if ! command -v adb >/dev/null 2>&1; then
  echo "adb not found. Install with: brew install --cask android-platform-tools" >&2
  exit 1
fi

if ! command -v scrcpy >/dev/null 2>&1; then
  echo "scrcpy not found. Install with: brew install scrcpy" >&2
  exit 1
fi

adb start-server >/dev/null

device=$(adb devices | awk 'NR>1 && $2=="device" {print $1; exit}')

if [[ -z "${device:-}" ]]; then
  echo "No authorized device found. Connect via USB and accept the debug prompt." >&2
  adb devices
  exit 1
fi

echo "Connecting to $device..."
exec scrcpy -s "$device" "$@"
