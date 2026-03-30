#!/usr/bin/env bash
# Claude Code audio hook — spoken summary using claude -p + ElevenLabs TTS
#
# Flow: Hook payload (stdin) -> claude -p Haiku (summarize) -> ElevenLabs TTS -> audio
#
# Works with any Claude Code auth method (Max, API key, Bedrock) — no extra
# credentials needed. The summarization runs through your existing claude CLI.
#
# Requires: jq, claude CLI, curl, ELEVENLABS_API_KEY env var

set -euo pipefail

# --- Configuration (override via environment variables) ---

tts_model="${TTS_MODEL:-eleven_turbo_v2_5}"

# All default ElevenLabs voices (male, female, neutral)
default_voices=(
  "EXAVITQu4vr4xnSDxMaL"  # Sarah - female, american
  "FGY2WhTYpPnrIDTdsKH5"  # Laura - female, american
  "XrExE9yKIg1WjnnlVkGX"  # Matilda - female, american
  "cgSgspJ2msm6clMCkdW9"  # Jessica - female, american
  "hpp4J3VqNfWAUOO0d1Us"  # Bella - female, american
  "Xb7hH8MSUJpSbSDYk0k2"  # Alice - female, british
  "pFZP5JQG7iQjIQuC4Bku"  # Lily - female, british
  "CwhRBWXzGAHq8TQ4Fs17"  # Roger - male, american
  "IKne3meq5aSn9XLyUdCD"  # Charlie - male, australian
  "JBFqnCBsd6RMkjVDRZzb"  # George - male, british
  "N2lVS1w4EtoT3dr4eOWO"  # Callum - male, american
  "SOYHLrjzK2X1ezoPC6cr"  # Harry - male, american
  "TX3LPaxmHKxFdv7VOQHJ"  # Liam - male, american
  "bIHbv24MWmeRgasZH58o"  # Will - male, american
  "cjVigY5qzO86Huf0OWal"  # Eric - male, american
  "iP95p4xoKVk53GoZ742B"  # Chris - male, american
  "nPczCjzI2devNBz1zQrb"  # Brian - male, american
  "onwK4e9ZLuTAKqWW03F9"  # Daniel - male, british
  "pNInz6obpgDQGcFmaJgB"  # Adam - male, american
  "pqHfZKP75CvOlQylNhV4"  # Bill - male, american
  "SAxJUlDKRc79XAyeWyMu"  # Morgan - male, american
  "2dfOetxQ16X5rqsIA5wN"  # Erik - male, mexican
  "SAz9YHcvj6GT2YYXdXww"  # River - neutral, american
)

# Allow override via VOICE_IDS (comma-separated)
if [ -n "${VOICE_IDS:-}" ]; then
  IFS=',' read -ra voices <<< "$VOICE_IDS"
else
  voices=("${default_voices[@]}")
fi

# --- Prerequisite checks ---

for cmd in jq claude curl; do
  if ! command -v "$cmd" &>/dev/null; then
    exit 0  # Fail silently — async hooks should not block Claude Code
  fi
done

if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
  exit 0
fi

# --- Temp file cleanup ---

tmpfile="/tmp/claude-tts-$$.mp3"
trap 'rm -f "$tmpfile"' EXIT

# --- Cross-platform audio player ---

play_audio() {
  if command -v afplay &>/dev/null; then
    afplay "$1"
  elif command -v paplay &>/dev/null; then
    paplay "$1"
  elif command -v aplay &>/dev/null; then
    aplay "$1"
  fi
}

# --- Main ---

input=$(cat)

# Skip short responses on Stop hook (TaskCompleted always runs)
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty')
if [ "$hook_event" = "Stop" ]; then
  msg_length=$(echo "$input" | jq -r '.last_assistant_message // "" | length')
  min_length="${STOP_MIN_MESSAGE_LENGTH:-100}"
  if [ "$msg_length" -lt "$min_length" ]; then
    exit 0
  fi
fi

# Extract context: last assistant message + recent transcript messages
# Extract last assistant message, strip markdown artifacts
summary=$(echo "$input" | jq -r '.last_assistant_message // empty' \
  | sed 's/```[^`]*```//g' \
  | sed 's/`[^`]*`//g' \
  | sed 's/[#*_\[\]()]//g' \
  | tr '\n' ' ' \
  | sed 's/  */ /g' \
  | head -c 300)

if [ -z "$summary" ] || [ "$summary" = "null" ]; then
  exit 0
fi

# Pick a random voice
voice_id="${voices[$((RANDOM % ${#voices[@]}))]}"

# Summarize with claude -p (uses your existing auth — Max, API, or Bedrock)
spoken=$(printf "You are a computer voice assistant. Read this text and reply with ONLY 3-7 words describing what was accomplished. No preamble, no quotes, no punctuation except periods. Examples of good replies: Status line configured. Repository pushed to GitHub. Hook scripts updated and tested.\n\nText: %s" "$summary" \
  | claude -p --model haiku 2>/dev/null \
  | tr -d '"*#' \
  | head -1)

if [ -z "$spoken" ] || [ "$spoken" = "null" ]; then
  exit 0
fi

# Speak with ElevenLabs
curl -s \
  -H "xi-api-key: $ELEVENLABS_API_KEY" \
  -H "Content-Type: application/json" \
  -X POST "https://api.elevenlabs.io/v1/text-to-speech/$voice_id" \
  -d "{\"text\":\"$spoken\",\"model_id\":\"$tts_model\"}" \
  --output "$tmpfile"

play_audio "$tmpfile"
