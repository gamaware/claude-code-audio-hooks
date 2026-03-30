# claude-code-audio-hooks

Audio feedback hooks for [Claude Code](https://claude.ai/code) — hear what Claude
did after every task completion.

Uses `claude -p` (Claude Code's one-shot CLI) to summarize what was done into a
brief announcement, then **ElevenLabs** text-to-speech to speak it aloud with a
randomly selected voice. No extra API keys or AWS credentials needed — it uses
your existing Claude Code authentication.

## What It Does

| Hook | Trigger | Action |
| --- | --- | --- |
| **Stop** | Any response with 100+ chars | Summarize + speak what was done |
| **TaskCompleted** | A tracked task finishes | Summarize + speak (always) |

Short responses (under 100 characters) stay silent to avoid noise.

### Example

You ask Claude to refactor a module. When it finishes, you hear:

> *"Authentication module refactored to use JWT tokens."*

— spoken by a randomly selected voice from a pool of 23 (male, female, neutral).

## How It Works

```
Claude Code emits Stop or TaskCompleted event
        |
        v
elevenlabs-speak.sh (async, non-blocking)
  1. Check: Stop event with short message? -> stay silent
  2. Read last 2-3 assistant messages from transcript for context
  3. claude -p --model haiku: summarize to ~10 words
  4. Pick random voice from pool (23 voices)
  5. ElevenLabs TTS: generate speech from summary
  6. Play audio (afplay / paplay / aplay)
```

The summarization runs through your existing `claude` CLI — it works with any
auth method (Max subscription, API key, or Bedrock). No extra credentials needed.

See [docs/architecture.md](docs/architecture.md) for detailed flow diagrams and
payload schemas.

## Prerequisites

- **Claude Code** installed and authenticated
- **macOS** or **Linux** (with PulseAudio or ALSA)
- **ElevenLabs** account with API key ([free tier](https://elevenlabs.io) works)
- **jq** (`brew install jq` / `apt install jq`)
- **curl**

## Quick Start

```bash
git clone https://github.com/gamaware/claude-code-audio-hooks.git
cd claude-code-audio-hooks

# Run the installer (copies hook to ~/.claude/hooks/)
./install.sh

# Set your ElevenLabs API key in ~/.claude/settings.json
# Merge config/settings-snippet.json into ~/.claude/settings.json
# Restart Claude Code

# Verify everything works
./test.sh
```

## Manual Setup

### 1. Copy the hook

```bash
mkdir -p ~/.claude/hooks
cp hooks/elevenlabs-speak.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/elevenlabs-speak.sh
```

### 2. Configure settings.json

Merge the following into your `~/.claude/settings.json`:

```json
{
  "env": {
    "ELEVENLABS_API_KEY": "your-elevenlabs-api-key"
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/elevenlabs-speak.sh",
            "async": true
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/elevenlabs-speak.sh",
            "async": true
          }
        ]
      }
    ]
  }
}
```

### 3. Set up ElevenLabs

See [docs/elevenlabs-setup.md](docs/elevenlabs-setup.md) for:

- Creating a free account
- Generating a restricted API key (only needs Text to Speech access)
- Browsing and selecting voices
- TTS model options

### 4. Restart Claude Code and verify

```bash
./test.sh
```

## Configuration

All settings are configurable via environment variables in `~/.claude/settings.json`:

| Variable | Default | Description |
| --- | --- | --- |
| `ELEVENLABS_API_KEY` | (required) | ElevenLabs API key |
| `TTS_MODEL` | `eleven_turbo_v2_5` | ElevenLabs TTS model |
| `VOICE_IDS` | (all 23 voices) | Comma-separated voice IDs to use |
| `STOP_MIN_MESSAGE_LENGTH` | `100` | Minimum message length (chars) to trigger voice on Stop |

### Custom Voice Selection

To use specific voices instead of all 23:

```json
{
  "env": {
    "VOICE_IDS": "EXAVITQu4vr4xnSDxMaL,hpp4J3VqNfWAUOO0d1Us"
  }
}
```

See [docs/elevenlabs-setup.md](docs/elevenlabs-setup.md) for the full voice catalog.

## Cost

| Service | Per call | Monthly (200 tasks) |
| --- | --- | --- |
| Summarization (`claude -p`) | Free (Max plan) | $0 |
| ElevenLabs TTS | ~50 characters | Free (10K chars/month free tier) |

On a **Max subscription**, this is completely free. On API billing, the Haiku
summarization costs ~$0.0001 per call (~$0.02/month at 200 tasks).

ElevenLabs free tier covers ~200 announcements/month (10,000 chars at ~50 chars each).

## Troubleshooting

| Issue | Cause | Fix |
| --- | --- | --- |
| No audio at all | Missing audio player | macOS has `afplay` built in; Linux: `apt install pulseaudio-utils` |
| Silence on all responses | `ELEVENLABS_API_KEY` not set | Add to settings.json env block |
| Silence on short responses | Expected behavior | Messages under 100 chars are silent on Stop |
| `claude -p` fails | Not logged in | Run `claude` and authenticate |
| ElevenLabs 401 | Invalid API key | Regenerate at elevenlabs.io |
| ElevenLabs 429 | Free tier exhausted | Wait for monthly reset or upgrade |

## Documentation

- [Architecture & Data Flow](docs/architecture.md)
- [ElevenLabs Setup](docs/elevenlabs-setup.md)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)

## License

[MIT](LICENSE)
