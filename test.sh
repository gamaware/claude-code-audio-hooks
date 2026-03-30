#!/usr/bin/env bash
# End-to-end test for Claude Code audio hooks
#
# Verifies prerequisites, AWS Bedrock access, ElevenLabs API, and audio playback.

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
check "aws CLI installed" command -v aws
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

# --- AWS Bedrock ---

echo "--- AWS Bedrock ---"

profile_flag=""
if [ -n "${AWS_PROFILE:-}" ]; then
  profile_flag="--profile $AWS_PROFILE"
  echo "[INFO] Using AWS profile: $AWS_PROFILE"
fi

region="${AWS_REGION:-us-east-1}"
model="${BEDROCK_MODEL_ID:-us.anthropic.claude-haiku-4-5-20251001-v1:0}"

# shellcheck disable=SC2086
if aws sts get-caller-identity $profile_flag &>/dev/null; then
  echo "[PASS] AWS credentials valid"
  ((pass++))
else
  echo "[FAIL] AWS credentials invalid or expired"
  echo "       Run: aws sso login --profile YOUR_PROFILE"
  ((fail++))
fi

bedrock_out="/tmp/claude-tts-test-$$.json"
trap 'rm -f "$bedrock_out" /tmp/claude-tts-test-$$.mp3' EXIT

# shellcheck disable=SC2086
if aws bedrock-runtime invoke-model \
  $profile_flag \
  --region "$region" \
  --model-id "$model" \
  --content-type application/json \
  --accept application/json \
  --body '{"anthropic_version":"bedrock-2023-05-31","max_tokens":10,"messages":[{"role":"user","content":"Say hello in 3 words"}]}' \
  "$bedrock_out" &>/dev/null; then

  spoken=$(jq -r '.content[0].text // empty' "$bedrock_out" 2>/dev/null)
  if [ -n "$spoken" ]; then
    echo "[PASS] Bedrock Haiku responded: $spoken"
    ((pass++))
  else
    echo "[FAIL] Bedrock returned empty response"
    ((fail++))
  fi
else
  echo "[FAIL] Bedrock invoke-model failed"
  echo "       Check model access: aws bedrock list-inference-profiles --region $region"
  ((fail++))
fi

echo ""

# --- ElevenLabs ---

echo "--- ElevenLabs ---"

if [ -n "${ELEVENLABS_API_KEY:-}" ]; then
  tts_out="/tmp/claude-tts-test-$$.mp3"
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
