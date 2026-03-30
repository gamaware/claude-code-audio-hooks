# claude-code-audio-hooks

Audio feedback hooks for [Claude Code](https://claude.ai/code) — hear what Claude
did after every task completion.

Uses **AWS Bedrock Haiku** to summarize what was done into a brief announcement,
then **ElevenLabs** text-to-speech to speak it aloud with a randomly selected voice.
Also plays a system sound notification on long responses.

## What It Does

| Hook | Trigger | Action |
| --- | --- | --- |
| **TaskCompleted** | A tracked task finishes | Bedrock summarizes the work, ElevenLabs speaks it |
| **Stop** | Any response > 10 seconds | Plays a macOS/Linux system sound |

### Example

You ask Claude to refactor a module. When it marks the task complete, you hear:

> *"Authentication module refactored to use JWT tokens."*

— spoken by a randomly selected voice from a pool of 23 (male, female, neutral).

## Architecture

```
Claude Code completes a task
        |
        v
elevenlabs-speak.sh (async, non-blocking)
  1. Extract last_assistant_message from hook payload
  2. Pick random voice from pool (23 voices)
  3. Bedrock Haiku: summarize to ~10 words
  4. ElevenLabs TTS: generate speech
  5. Play audio (afplay / paplay / aplay)
```

See [docs/architecture.md](docs/architecture.md) for detailed flow diagrams and
payload schemas.

## Prerequisites

- **macOS** or **Linux** (with PulseAudio or ALSA)
- **AWS CLI v2** with credentials configured
- **AWS Bedrock** access with Claude Haiku enabled
- **ElevenLabs** account with API key (free tier works)
- **jq** (`brew install jq` / `apt install jq`)
- **curl**

## Quick Start

```bash
# Clone the repo
git clone https://github.com/gamaware/claude-code-audio-hooks.git
cd claude-code-audio-hooks

# Run the installer
./install.sh

# Set your ElevenLabs API key in ~/.claude/settings.json
# Merge config/settings-snippet.json into ~/.claude/settings.json
# Restart Claude Code

# Verify everything works
./test.sh
```

## Manual Setup

### 1. Copy hooks

```bash
mkdir -p ~/.claude/hooks
cp hooks/elevenlabs-speak.sh ~/.claude/hooks/
cp hooks/stop-sound.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/elevenlabs-speak.sh
chmod +x ~/.claude/hooks/stop-sound.sh
```

### 2. Configure settings.json

Merge the following into your `~/.claude/settings.json`:

```json
{
  "env": {
    "ELEVENLABS_API_KEY": "your-elevenlabs-api-key",
    "AWS_PROFILE": "your-aws-profile",
    "AWS_REGION": "us-east-1"
  },
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ~/.claude/hooks/stop-sound.sh",
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

### 3. Set up AWS Bedrock

See [docs/bedrock-setup.md](docs/bedrock-setup.md) for:

- Enabling Claude Haiku model access
- IAM policy with minimum permissions
- Credential configuration (SSO, access keys, env vars)
- Region and model ID configuration

### 4. Set up ElevenLabs

See [docs/elevenlabs-setup.md](docs/elevenlabs-setup.md) for:

- Creating an account (free tier)
- Generating a restricted API key
- Browsing and selecting voices
- TTS model options

### 5. Restart Claude Code

```bash
# Exit and restart to load new hooks and env vars
claude
```

### 6. Verify

```bash
./test.sh
```

## Configuration

All settings are configurable via environment variables in `~/.claude/settings.json`:

| Variable | Default | Description |
| --- | --- | --- |
| `ELEVENLABS_API_KEY` | (required) | ElevenLabs API key |
| `AWS_PROFILE` | (default chain) | AWS CLI profile for Bedrock |
| `AWS_REGION` | `us-east-1` | AWS region for Bedrock |
| `BEDROCK_MODEL_ID` | `us.anthropic.claude-haiku-4-5-20251001-v1:0` | Bedrock model for summarization |
| `TTS_MODEL` | `eleven_turbo_v2_5` | ElevenLabs TTS model |
| `VOICE_IDS` | (all 23 voices) | Comma-separated voice IDs to use |
| `STOP_SOUND_FILE` | `/System/Library/Sounds/Submarine.aiff` | Sound file for Stop hook |
| `STOP_DURATION_THRESHOLD_MS` | `10000` | Minimum response duration to trigger sound (ms) |

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
| AWS Bedrock Haiku | ~$0.0001 | ~$0.02 |
| ElevenLabs TTS | ~50 characters | Free (10K chars/month) |

At typical usage (200 task completions/month), this costs **2 cents on AWS** and
**nothing on ElevenLabs** (free tier).

## macOS System Sounds

Available sounds for the Stop hook (set via `STOP_SOUND_FILE`):

Basso, Blow, Bottle, Frog, Funk, Glass, Hero, Morse, Ping, Pop, Purr, Sosumi,
Submarine, Tink

Path: `/System/Library/Sounds/<Name>.aiff`

Preview any sound: `afplay /System/Library/Sounds/Glass.aiff`

## Troubleshooting

| Issue | Cause | Fix |
| --- | --- | --- |
| No audio at all | Missing audio player | Install `afplay` (macOS built-in) or `pulseaudio-utils` (Linux) |
| Silence on task complete | `ELEVENLABS_API_KEY` not set | Add to settings.json env block |
| "Task complete" only | Bedrock call failing | Check `AWS_PROFILE` and `AWS_REGION` |
| AWS auth error | Expired credentials | `aws sso login --profile your-profile` |
| ElevenLabs 429 | Free tier exhausted | Wait for monthly reset or upgrade plan |
| Sound but no voice | Hook only on Stop, not TaskCompleted | Check hooks config in settings.json |

## Documentation

- [Architecture & Data Flow](docs/architecture.md)
- [AWS Bedrock Setup](docs/bedrock-setup.md)
- [ElevenLabs Setup](docs/elevenlabs-setup.md)
- [Claude Code Hooks Reference](https://code.claude.com/docs/en/hooks)
- [Claude Code on Amazon Bedrock](https://code.claude.com/docs/en/amazon-bedrock)

## License

[MIT](LICENSE)
