# ElevenLabs Setup for Audio Hooks

This hook uses ElevenLabs text-to-speech API to speak task completion summaries
aloud. This guide covers account creation, API key setup, and voice configuration.

## Step 1: Create an ElevenLabs Account

1. Go to [elevenlabs.io](https://elevenlabs.io)
2. Sign up for a free account
3. The free tier includes **10,000 characters/month** — enough for ~200 task
   completion announcements

## Step 2: Create an API Key

1. Log in to [elevenlabs.io](https://elevenlabs.io)
2. Click your profile icon (bottom-left or top-right)
3. Go to **Profile + API key**
4. Click **Create API Key**
5. Configure the key:

| Setting | Value |
| --- | --- |
| Name | `ClaudeCode` (or any name) |
| Restrict Key | **On** (recommended) |
| Text to Speech | **Access** |
| All other endpoints | **No Access** |

6. Click **Create Key**
7. Copy the key (starts with `sk_`)

## Step 3: Add API Key to Claude Code

Add the key to your `~/.claude/settings.json`:

```json
{
  "env": {
    "ELEVENLABS_API_KEY": "sk_your_api_key_here"
  }
}
```

## Step 4: Choose Your Voices (Optional)

By default, the hook rotates through all 23 built-in ElevenLabs voices. To use
a custom subset, set the `VOICE_IDS` environment variable with comma-separated
voice IDs:

```json
{
  "env": {
    "VOICE_IDS": "EXAVITQu4vr4xnSDxMaL,hpp4J3VqNfWAUOO0d1Us,SAz9YHcvj6GT2YYXdXww"
  }
}
```

### Default Voice Pool

#### Female

| Name | Style | Accent | Voice ID |
| --- | --- | --- | --- |
| Sarah | Mature, confident | American | `EXAVITQu4vr4xnSDxMaL` |
| Laura | Enthusiastic, quirky | American | `FGY2WhTYpPnrIDTdsKH5` |
| Matilda | Professional, knowledgeable | American | `XrExE9yKIg1WjnnlVkGX` |
| Jessica | Playful, warm | American | `cgSgspJ2msm6clMCkdW9` |
| Bella | Professional, bright | American | `hpp4J3VqNfWAUOO0d1Us` |
| Alice | Clear, educator | British | `Xb7hH8MSUJpSbSDYk0k2` |
| Lily | Velvety, actress | British | `pFZP5JQG7iQjIQuC4Bku` |

#### Male

| Name | Style | Accent | Voice ID |
| --- | --- | --- | --- |
| Roger | Laid-back, casual | American | `CwhRBWXzGAHq8TQ4Fs17` |
| Charlie | Deep, confident | Australian | `IKne3meq5aSn9XLyUdCD` |
| George | Warm storyteller | British | `JBFqnCBsd6RMkjVDRZzb` |
| Callum | Husky trickster | American | `N2lVS1w4EtoT3dr4eOWO` |
| Harry | Fierce warrior | American | `SOYHLrjzK2X1ezoPC6cr` |
| Liam | Energetic creator | American | `TX3LPaxmHKxFdv7VOQHJ` |
| Will | Relaxed optimist | American | `bIHbv24MWmeRgasZH58o` |
| Eric | Smooth, trustworthy | American | `cjVigY5qzO86Huf0OWal` |
| Chris | Charming, down-to-earth | American | `iP95p4xoKVk53GoZ742B` |
| Brian | Deep, comforting | American | `nPczCjzI2devNBz1zQrb` |
| Daniel | Steady broadcaster | British | `onwK4e9ZLuTAKqWW03F9` |
| Adam | Dominant, firm | American | `pNInz6obpgDQGcFmaJgB` |
| Bill | Wise, mature | American | `pqHfZKP75CvOlQylNhV4` |
| Erik | Entertainment host | Mexican | `2dfOetxQ16X5rqsIA5wN` |
| Morgan | Deep storyteller | American | `SAxJUlDKRc79XAyeWyMu` |

#### Neutral

| Name | Style | Accent | Voice ID |
| --- | --- | --- | --- |
| River | Relaxed, informative | American | `SAz9YHcvj6GT2YYXdXww` |

### Browse More Voices

ElevenLabs has thousands of community voices. Browse them at:

1. Log in to [elevenlabs.io](https://elevenlabs.io)
2. Click **Voices** in the left sidebar
3. Browse or search the voice library
4. Click a voice to hear a preview
5. Copy the voice ID from the URL or voice settings

## TTS Model Configuration

The default model is `eleven_turbo_v2_5` (fastest, lowest latency). Override if needed:

```json
{
  "env": {
    "TTS_MODEL": "eleven_turbo_v2_5"
  }
}
```

Available models:

| Model | Speed | Quality |
| --- | --- | --- |
| `eleven_turbo_v2_5` | Fastest | Good (default) |
| `eleven_multilingual_v2` | Slower | Best (29 languages) |
| `eleven_monolingual_v1` | Medium | English only |

## Cost

| Tier | Characters/month | Price |
| --- | --- | --- |
| Free | 10,000 | $0 |
| Starter | 30,000 | $5/month |
| Creator | 100,000 | $22/month |

Each task completion uses ~50 characters. The free tier supports ~200 announcements/month.

## Troubleshooting

| Issue | Solution |
| --- | --- |
| No audio output | Check `ELEVENLABS_API_KEY` is set and valid |
| HTTP 401 | API key is invalid or expired — regenerate it |
| HTTP 429 | Rate limited — you hit the free tier character limit |
| HTTP 422 | Text is empty or malformed — check Bedrock summarization step |
| Wrong voice | Verify voice IDs in the `VOICE_IDS` env var |

## References

- [ElevenLabs API Docs](https://elevenlabs.io/docs/api-reference/text-to-speech)
- [ElevenLabs Pricing](https://elevenlabs.io/pricing)
- [Voice Library](https://elevenlabs.io/voice-library)
