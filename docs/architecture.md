# Architecture

## How Claude Code Hooks Work

Claude Code emits events at key moments during a session. You can attach shell
commands to these events via `hooks` in `~/.claude/settings.json`. Each hook
receives a JSON payload on stdin with context about the event.

Hooks run **asynchronously** (`"async": true`), meaning they do not block Claude
Code from continuing to work.

## Data Flow

### Full Pipeline

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant Hook as elevenlabs-speak.sh
    participant BR as AWS Bedrock Haiku
    participant EL as ElevenLabs TTS
    participant Speaker as Audio Player

    CC->>Hook: Event (Stop/TaskCompleted) + JSON payload
    Hook->>Hook: Check lockfile (debounce)
    Hook->>Hook: Check message length (Stop only)
    Hook->>Hook: Strip markdown from message
    Hook->>BR: Summarize to 8-15 words
    BR-->>Hook: "Bedrock hook restored with voice rotation."
    Hook->>Hook: Pick random voice from pool
    Hook->>EL: POST /v1/text-to-speech/{voice_id}
    EL-->>Hook: MP3 audio file
    Hook->>Speaker: afplay / paplay / aplay
    Speaker-->>Hook: Audio plays
```

### Decision Flow

```mermaid
flowchart TD
    A[Claude Code emits event] --> B{Lockfile exists?}
    B -->|Yes, < 15s old| Z[Exit - debounce]
    B -->|No or expired| C[Create lockfile]
    C --> D{Event type?}
    D -->|Stop| E{Message > 100 chars?}
    D -->|TaskCompleted| F[Continue]
    E -->|No| Z2[Exit - too short]
    E -->|Yes| F
    F --> G[Strip markdown from message]
    G --> H[Bedrock Haiku: summarize to 8-15 words]
    H --> I{Summary empty?}
    I -->|Yes| Z3[Exit - no summary]
    I -->|No| J[Pick random voice]
    J --> K[ElevenLabs TTS: generate audio]
    K --> L[Play audio]
    L --> M[Remove lockfile]
```

### Component Overview

```mermaid
graph LR
    subgraph "Claude Code"
        A[Stop Event] --> H[Hook Runner]
        B[TaskCompleted Event] --> H
    end

    subgraph "elevenlabs-speak.sh"
        H --> C[Debounce Check]
        C --> D[Message Filter]
        D --> E[Markdown Stripper]
    end

    subgraph "External APIs"
        E --> F[AWS Bedrock Haiku]
        F --> G[ElevenLabs TTS]
    end

    G --> I[Audio Player]
```

## Hook Payload Schemas

### Stop Payload

Received on every Claude Code response.

```json
{
  "cwd": "/current/working/directory",
  "hook_event_name": "Stop",
  "last_assistant_message": "Full text of Claude's last response...",
  "permission_mode": "default",
  "session_id": "uuid",
  "stop_hook_active": true,
  "transcript_path": "/path/to/session.jsonl"
}
```

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

## Debounce Mechanism

When both `Stop` and `TaskCompleted` fire for the same response (common during
plan mode), the lockfile prevents duplicate announcements:

```mermaid
sequenceDiagram
    participant CC as Claude Code
    participant S as Stop Hook
    participant T as TaskCompleted Hook
    participant Lock as /tmp/claude-tts.lock

    CC->>S: Stop event
    CC->>T: TaskCompleted event
    S->>Lock: Check lockfile
    Note over Lock: No lockfile exists
    S->>Lock: Create lockfile
    S->>S: Process and play audio
    T->>Lock: Check lockfile
    Note over Lock: Lockfile < 15s old
    T->>T: Exit (debounced)
    S->>Lock: Remove lockfile
```

## Performance

```mermaid
gantt
    title Pipeline Latency (async, non-blocking)
    dateFormat X
    axisFormat %L ms

    section Processing
    JSON parsing + markdown strip : 0, 50
    section Bedrock
    Haiku summarization          : 50, 1500
    section ElevenLabs
    TTS generation               : 1500, 2500
    section Playback
    Audio output                 : 2500, 4500
```

| Step | Typical latency |
| --- | --- |
| Hook trigger + JSON parsing | < 50ms |
| Bedrock Haiku summarization | 500ms - 1.5s |
| ElevenLabs TTS generation | 500ms - 1s |
| Audio playback | 1 - 2s |
| **Total** | **2 - 4s** |

Since hooks run asynchronously, this does not block your next prompt.

## Available Hook Events

This project uses `Stop` and `TaskCompleted`. Other events you could extend to:

| Event | Potential use |
| --- | --- |
| `SessionStart` | Greeting announcement |
| `SessionEnd` | Farewell announcement |
| `Notification` | Speak notifications aloud |
| `SubagentStop` | Announce when a subagent finishes |

## Security Considerations

- API keys are stored in `~/.claude/settings.json` env block, not in scripts
- Scripts read keys from environment variables at runtime
- Only a truncated, markdown-stripped summary (max 400 chars) is sent to Bedrock
- ElevenLabs receives only the ~10 word summary, not the full conversation
- Temp files are cleaned up via `trap` on EXIT
- All API calls use HTTPS
