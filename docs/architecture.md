# Architecture

## How Claude Code Hooks Work

Claude Code emits events at key moments during a session. You can attach shell
commands to these events via `hooks` in `~/.claude/settings.json`. Each hook
receives a JSON payload on stdin with context about the event.

Hooks run **asynchronously** (`"async": true`), meaning they do not block Claude
Code from continuing to work. You hear the audio 2-4 seconds after the event
while you keep working.

## How This Hook Works

A single script (`elevenlabs-speak.sh`) handles both `Stop` and `TaskCompleted`
events. It uses the `claude` CLI itself for summarization — no external API keys
or AWS credentials needed beyond your existing Claude Code auth.

```
Claude Code emits an event (Stop or TaskCompleted)
        |
        v
elevenlabs-speak.sh receives JSON on stdin
        |
        v
Is this a Stop event with duration < 10s?
  Yes -> exit (stay silent on short responses)
  No  -> continue
        |
        v
Extract context from:
  1. last_assistant_message (from hook payload)
  2. Last 2-3 assistant messages from transcript (for richer context)
        |
        v
Pick a random voice from pool (23 voices)
        |
        v
claude -p --model haiku
  "Summarize in under 10 words: <context>"
  -> "Config file updated with new hooks."
        |
        v
ElevenLabs TTS API
  POST /v1/text-to-speech/<voice_id>
  -> MP3 audio file
        |
        v
Play audio (afplay / paplay / aplay)
```

## Why `claude -p` Instead of a Separate API Call

The hook runs as a standalone bash script — it has no access to the Claude Code
session or conversation context. It needs an LLM to summarize the work into a
brief spoken announcement.

Previous versions used AWS Bedrock to call Haiku directly. The current approach
uses `claude -p` (Claude Code's one-shot CLI mode) instead:

| | `claude -p` | Bedrock API |
| --- | --- | --- |
| Auth | Uses existing Claude Code auth | Needs separate AWS credentials |
| Cost (Max plan) | Free (included in subscription) | ~$0.0001/call |
| Cost (API plan) | Uses your API key | Uses your AWS account |
| Setup | None (claude CLI already installed) | IAM policy, model access, profile |
| Speed | ~1-2s (includes CLI startup) | ~0.5-1.5s |

The `claude -p` approach is simpler, requires no extra configuration, and is
free for Max subscribers.

## Hook Payload Schemas

### Stop Payload

Received on every Claude Code response.

```json
{
  "cwd": "/current/working/directory",
  "hook_event_name": "Stop",
  "last_assistant_message": "Full text of Claude's last response...",
  "duration_ms": 15000,
  "permission_mode": "default",
  "session_id": "uuid",
  "stop_hook_active": true,
  "transcript_path": "/path/to/session.jsonl"
}
```

Key fields:
- `duration_ms` — used to skip short responses (threshold: 10 seconds)
- `last_assistant_message` — primary source for summarization
- `transcript_path` — JSONL file read for richer context (last 2-3 messages)

### TaskCompleted Payload

Received when a tracked task is marked complete (e.g., during plan mode).

```json
{
  "cwd": "/current/working/directory",
  "hook_event_name": "TaskCompleted",
  "last_assistant_message": "Full text of Claude's last response...",
  "permission_mode": "default",
  "session_id": "uuid",
  "transcript_path": "/path/to/session.jsonl"
}
```

Note: No `duration_ms` field — TaskCompleted always triggers the voice.

## Transcript Context Enrichment

The script reads the last 20 lines of the transcript JSONL file and extracts the
last 2-3 assistant messages. This provides richer context than `last_assistant_message`
alone, especially when the final message is brief (e.g., "Done.") but the real
work was described in earlier messages.

## Available Hook Events

Claude Code supports many hook events. This project uses two:

| Event | Behavior in this project |
| --- | --- |
| `Stop` | Voice summary if response > 10s, silent otherwise |
| `TaskCompleted` | Voice summary always |

Other events you could extend this to:

| Event | Potential use |
| --- | --- |
| `SessionStart` | "Session started" greeting |
| `SessionEnd` | "Session ended" farewell |
| `Notification` | Speak notifications aloud |
| `SubagentStop` | Announce when a subagent finishes |

## Performance

| Step | Typical latency |
| --- | --- |
| Hook trigger + JSON parsing | < 50ms |
| Transcript reading | < 100ms |
| `claude -p` summarization | 1 - 2s |
| ElevenLabs TTS generation | 500ms - 1s |
| Audio playback | 1 - 2s |
| **Total** | **3 - 5s** |

Since hooks run asynchronously, this does not block your next prompt.

## Security Considerations

- The `ELEVENLABS_API_KEY` is stored in `~/.claude/settings.json` env block, not
  in the script itself
- The script reads conversation content locally and only sends a truncated summary
  (max 400 chars) to the `claude` CLI for summarization
- ElevenLabs receives only the ~10 word summary, not the full conversation
- Temp files are cleaned up via `trap` on EXIT
- All API calls use HTTPS
