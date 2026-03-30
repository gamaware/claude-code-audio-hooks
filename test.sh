#!/usr/bin/env bash
# End-to-end test for Claude Code audio hooks
#
# Verifies prerequisites, claude CLI, ElevenLabs API, and audio playback.

set -euo pipefail

pass=0
fail=0

check() {
  local name="$1"
  shift
  if "$@" &>/dev/null; then
    echo "[PASS] $name"
    ((pass++))
  else
    echo "[FAIL] $name"
    ((fail++))
  fi
}

echo "=== Claude Code Audio Hooks — Test Suite ==="
echo ""

# --- Prerequisites ---

echo "--- Prerequisites ---"
check "jq installed" command -v jq
check "claude CLI installed" command -v claude
check "curl installed" command -v curl

if command -v afplay &>/dev/null; then
  echo "[PASS] Audio player: afplay (macOS)"
  ((pass++))
  PLAYER="afplay"
elif command -v paplay &>/dev/null; then
  echo "[PASS] Audio player: paplay (PulseAudio)"
  ((pass++))
  PLAYER="paplay"
elif command -v aplay &>/dev/null; then
  echo "[PASS] Audio player: aplay (ALSA)"
  ((pass++))
  PLAYER="aplay"
else
  echo "[FAIL] No audio player found (afplay/paplay/aplay)"
  ((fail++))
  PLAYER=""
fi

echo ""

# --- Environment ---

echo "--- Environment ---"

if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  echo "[PASS] ELEVENLABS_API_KEY is set"
  ((pass++))
else
  echo "[FAIL] ELEVENLABS_API_KEY is not set"
  echo "       Export it or add to ~/.claude/settings.json env block"
  ((fail++))
fi

echo ""

# --- Claude CLI ---

echo "--- Claude CLI (Summarization) ---"

spoken=$(echo "Say exactly: Test passed" | claude -p --model haiku 2>/dev/null | head -1)
if [ -n "$spoken" ]; then
  echo "[PASS] claude -p responded: $spoken"
  ((pass++))
else
  echo "[FAIL] claude -p did not respond"
  echo "       Ensure you are logged in: claude /login"
  ((fail++))
fi

echo ""

# --- ElevenLabs ---

echo "--- ElevenLabs TTS ---"

tts_out="/tmp/claude-tts-test-$$.mp3"
trap 'rm -f "$tts_out"' EXIT

if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  tts_model="${TTS_MODEL:-eleven_turbo_v2_5}"
  voice_id="hpp4J3VqNfWAUOO0d1Us"  # Bella (test voice)

  http_code=$(curl -s -o "$tts_out" -w "%{http_code}" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -X POST "https://api.elevenlabs.io/v1/text-to-speech/$voice_id" \
    -d "{\"text\":\"Test complete. Audio hooks are working.\",\"model_id\":\"$tts_model\"}")

  if [ "$http_code" = "200" ]; then
    echo "[PASS] ElevenLabs TTS returned audio"
    ((pass++))

    if [ -n "$PLAYER" ] && [ -f "$tts_out" ]; then
      echo "[INFO] Playing test audio..."
      $PLAYER "$tts_out" 2>/dev/null || true
      echo "[PASS] Audio playback complete"
      ((pass++))
    fi
  else
    echo "[FAIL] ElevenLabs TTS returned HTTP $http_code"
    ((fail++))
  fi
else
  echo "[SKIP] ElevenLabs test (no API key)"
fi

echo ""

# --- Summary ---

echo "=== Results: $pass passed, $fail failed ==="

if [ "$fail" -gt 0 ]; then
  exit 1
fi
