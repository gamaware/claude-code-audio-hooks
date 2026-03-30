#!/usr/bin/env bash
# Claude Code TaskCompleted hook — spoken summary using Bedrock + ElevenLabs
#
# Flow: Hook payload (stdin) -> Bedrock Haiku (summarize) -> ElevenLabs TTS -> audio playback
# Requires: jq, aws CLI, curl, ELEVENLABS_API_KEY env var

set -euo pipefail

# --- Configuration (override via environment variables) ---

tts_model="${TTS_MODEL:-eleven_turbo_v2_5}"
aws_region="${AWS_REGION:-us-east-1}"
bedrock_model="${BEDROCK_MODEL_ID:-us.anthropic.claude-haiku-4-5-20251001-v1:0}"

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

for cmd in jq aws curl; do
  if ! command -v "$cmd" &>/dev/null; then
    exit 0  # Fail silently — async hooks should not block Claude Code
  fi
done

if [ -z "${ELEVENLABS_API_KEY:-}" ]; then
  exit 0
fi

# --- Temp file cleanup ---

tmpfile="/tmp/claude-tts-$$.mp3"
bedrock_out="/tmp/claude-tts-bedrock-$$.json"
trap 'rm -f "$tmpfile" "$bedrock_out"' EXIT

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

# Extract the assistant's last message from the hook payload
summary=$(echo "$input" | jq -r '.last_assistant_message // empty' | head -c 500)

if [ -z "$summary" ] || [ "$summary" = "null" ]; then
  exit 0
fi

# Escape for JSON embedding
summary_escaped=$(echo "$summary" | tr '\n' ' ' | sed 's/"/\\"/g' | head -c 400)

# Pick a random voice
voice_id="${voices[$((RANDOM % ${#voices[@]}))]}"

# Build AWS profile flag (only if AWS_PROFILE is set)
profile_flag=""
if [ -n "${AWS_PROFILE:-}" ]; then
  profile_flag="--profile $AWS_PROFILE"
fi

# Summarize with Bedrock Haiku
# shellcheck disable=SC2086
aws bedrock-runtime invoke-model \
  $profile_flag \
  --region "$aws_region" \
  --model-id "$bedrock_model" \
  --content-type application/json \
  --accept application/json \
  --body "{\"anthropic_version\":\"bedrock-2023-05-31\",\"max_tokens\":30,\"messages\":[{\"role\":\"user\",\"content\":\"Summarize what was done into a single brief spoken announcement, under 10 words, like a computer assistant would say to a developer. No quotes, no markdown. Example: Settings file updated with new hooks. Here is what was done: $summary_escaped\"}]}" \
  "$bedrock_out" >/dev/null 2>&1

spoken=$(jq -r '.content[0].text // empty' "$bedrock_out" 2>/dev/null)

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
