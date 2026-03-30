#!/usr/bin/env bash
# Claude Code Stop hook — plays a system sound when responses take longer than a threshold
#
# Triggered on every Claude Code response. Only plays if duration exceeds the threshold.
# Requires: jq

set -euo pipefail

# --- Configuration (override via environment variables) ---

sound_file="${STOP_SOUND_FILE:-/System/Library/Sounds/Submarine.aiff}"
threshold="${STOP_DURATION_THRESHOLD_MS:-10000}"

# --- Prerequisite checks ---

if ! command -v jq &>/dev/null; then
  exit 0
fi

# --- Cross-platform audio player ---

play_audio() {
  if command -v afplay &>/dev/null; then
    afplay "$1" &
  elif command -v paplay &>/dev/null; then
    paplay "$1" &
  elif command -v aplay &>/dev/null; then
    aplay "$1" &
  fi
}

# --- Main ---

input=$(cat)

duration=$(echo "$input" | jq -r '.duration_ms // 0')

if [ "$duration" -gt "$threshold" ]; then
  if [ -f "$sound_file" ]; then
    play_audio "$sound_file"
  fi
fi
