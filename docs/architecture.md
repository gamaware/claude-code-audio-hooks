# Architecture

## How Claude Code Hooks Work

Claude Code emits events at key moments during a session. You can attach shell
commands to these events via `hooks` in `~/.claude/settings.json`. Each hook
receives a JSON payload on stdin with context about the event.

Hooks run **asynchronously** by default (`"async": true`), meaning they do not
block Claude Code from continuing to work.

## Data Flow

### TaskCompleted Hook (Voice Summary)

```
Claude Code completes a tracked task
        |
        v
Hook receives JSON on stdin
  { "last_assistant_message": "I updated the config..." }
        |
        v
elevenlabs-speak.sh
  1. Extract last_assistant_message (jq)
  2. Pick a random voice from the pool
  3. Send to Bedrock Haiku for summarization
     -> "Config file updated with new settings."
  4. Send summary to ElevenLabs TTS
     -> MP3 audio file
  5. Play audio (afplay/paplay/aplay)
```

### Stop Hook (System Sound)

```
Claude Code finishes a response
        |
        v
Hook receives JSON on stdin
  { "duration_ms": 15000 }
        |
        v
stop-sound.sh
  1. Extract duration_ms (jq)
  2. Compare against threshold (default 10s)
  3. If exceeded, play system sound
```

## Hook Payload Schemas

### TaskCompleted Payload

```json
{
  "cwd": "/current/working/directory",
  "hook_event_name": "TaskCompleted",
  "last_assistant_message": "Full text of Claude's last response...",
  "permission_mode": "default",
  "session_id": "fa990929-766b-4854-a6fa-9c749d08fcc7",
  "transcript_path": "/path/to/session.jsonl"
}
```

### Stop Payload

```json
{
  "cwd": "/current/working/directory",
  "hook_event_name": "Stop",
  "last_assistant_message": "Full text of Claude's last response...",
  "duration_ms": 15000,
  "permission_mode": "default",
  "session_id": "fa990929-766b-4854-a6fa-9c749d08fcc7",
  "stop_hook_active": true,
  "transcript_path": "/path/to/session.jsonl"
}
```

## Available Hook Events

Claude Code supports these hook events (among others):

| Event | When it fires |
| --- | --- |
| `Stop` | After every Claude response |
| `TaskCompleted` | When a tracked task is marked complete |
| `PreToolUse` | Before a tool is executed |
| `PostToolUse` | After a tool is executed |
| `SessionStart` | When a new session begins |
| `SessionEnd` | When a session ends |
| `Notification` | When Claude sends a notification |

## Security Considerations

- API keys are stored in `~/.claude/settings.json` env block, not in the scripts
- Scripts read keys from environment variables at runtime
- The hook payload may contain conversation content — scripts process it locally
  and only send a truncated summary (max 400 chars) to Bedrock
- Bedrock and ElevenLabs calls use HTTPS
- Temp files are cleaned up via `trap` on EXIT

## Performance

| Step | Typical latency |
| --- | --- |
| Hook trigger + JSON parsing | < 50ms |
| Bedrock Haiku summarization | 500ms - 1.5s |
| ElevenLabs TTS generation | 500ms - 1s |
| Audio playback | 1 - 2s |
| **Total** | **2 - 4s** |

Since hooks run asynchronously, this latency does not block your next prompt.
You hear the audio 2-4 seconds after the task completes while you continue working.
