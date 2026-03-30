#!/usr/bin/env bash
# Install Claude Code audio hooks
#
# Copies the hook script to ~/.claude/hooks/ and prints setup instructions.
# Does NOT modify settings.json — you must merge the config manually.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_DIR="$HOME/.claude/hooks"

echo "=== Claude Code Audio Hooks Installer ==="
echo ""

# --- Check prerequisites ---

missing=()
for cmd in jq claude curl; do
  if ! command -v "$cmd" &>/dev/null; then
    missing+=("$cmd")
  else
    echo "[OK] $cmd"
  fi
done

# Check for audio player
if command -v afplay &>/dev/null; then
  echo "[OK] Audio player: afplay (macOS)"
elif command -v paplay &>/dev/null; then
  echo "[OK] Audio player: paplay (PulseAudio)"
elif command -v aplay &>/dev/null; then
  echo "[OK] Audio player: aplay (ALSA)"
else
  missing+=("audio player (afplay/paplay/aplay)")
fi

if [ ${#missing[@]} -gt 0 ]; then
  echo ""
  echo "[WARN] Missing prerequisites: ${missing[*]}"
  echo "       Install them before using the hooks."
  echo ""
fi

# --- Copy hook ---

mkdir -p "$HOOKS_DIR"

cp "$SCRIPT_DIR/hooks/elevenlabs-speak.sh" "$HOOKS_DIR/"
chmod +x "$HOOKS_DIR/elevenlabs-speak.sh"

echo ""
echo "[OK] Hook installed to $HOOKS_DIR/elevenlabs-speak.sh"
echo ""

# --- Print next steps ---

echo "=== Next Steps ==="
echo ""
echo "1. Get an ElevenLabs API key (free tier works):"
echo "   See docs/elevenlabs-setup.md for step-by-step instructions."
echo ""
echo "2. Add your API key to ~/.claude/settings.json:"
echo ""
echo "   \"env\": {"
echo "     \"ELEVENLABS_API_KEY\": \"your-key-here\""
echo "   }"
echo ""
echo "3. Add the hooks config to ~/.claude/settings.json."
echo "   See config/settings-snippet.json for the block to merge."
echo ""
echo "4. Restart Claude Code to load the new hooks."
echo ""
echo "5. Run ./test.sh to verify everything works."
echo ""
echo "=== Done ==="
