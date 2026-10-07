# Audio captures

These bodies were captured with curl from the speech, transcriptions, and
translations endpoints at `https://api.openai.com/v1/audio`. Binary audio,
JSON, text, subtitles, and SSE bodies are saved unchanged. `Requests/` records
request JSON or multipart field values. `cases.json` records endpoints,
expected statuses, media types, and terminal events. `captures.json` records
actual statuses, media types, and UTC capture times.

See the official [speech guide](https://developers.openai.com/api/docs/guides/text-to-speech)
and [transcription and translation guide](https://developers.openai.com/api/docs/guides/speech-to-text).

| Scenarios | HTTP status | Coverage |
| --- | --- | --- |
| speech-wav, speech-mp3, speech-pcm, speech-aac, speech-flac, speech-opus | 200 | All six speech formats and response media types |
| speech-german | 200 | German speech used as translation input |
| speech-stream | 200 | Base64 PCM chunks, final token usage, `[DONE]` |
| transcription-json | 200 | Language detection and duration usage |
| transcription-logprobs | 200 | Token probabilities, bytes, token usage |
| transcription-verbose | 200 | Word and segment timestamps, segment probabilities |
| transcription-text, transcription-srt, transcription-vtt | 200 | Plain text and subtitles; all return `text/plain` |
| transcription-diarized | 200 | Speaker labels, segment IDs and times, token usage |
| transcription-stream | 200 | Text deltas and probabilities, final text and token usage |
| transcription-diarized-stream | 200 | Speaker segment events and final text |
| transcription-language-stream | 200 | Text deltas, final languages and duration usage |
| translation-json, translation-verbose | 200 | German to English translation and segment timestamps |
| translation-text, translation-vtt | 200 | Plain English text and subtitles |
| speech-missing-input | 400 | Missing required parameter |
| speech-unauthenticated | 401 | Missing authentication; no credential sent |
| transcription-missing-file, transcription-invalid-format | 400 | Multipart validation failures with null code and parameter |
| translation-invalid-model | 404 | Unsupported model, extra `detail` error object |

Speech uses `gpt-4o-mini-tts` and the built-in `alloy` voice. The short English
and German WAV captures are reused as uploads. Transcription uses `gpt-transcribe`,
`gpt-4o-mini-transcribe`, `gpt-4o-transcribe-diarize`, and `whisper-1`; translation
uses `whisper-1`. The recordings contain only the fixture sentence.

## Schema corrections

The overlay supplies missing discriminator mappings for speech events,
transcription events, and diarized usage. It also extends the terminal
transcription event's usage schema to accept both token usage and duration
usage: the newer `gpt-transcribe` stream reports `type: duration`.

The translation response's original `oneOf` branches overlap: verbose JSON
also satisfies the simple schema requiring only `text`. The generated decoder
selected the simple branch and discarded duration, language, and segments.
The overlay uses `anyOf`, matching the transcription endpoint's schema and
preserving both typed views. Tests require the verbose and diarized views
explicitly so successful decoding of just the simple text view cannot hide
lost fields.

Multipart array field names include brackets on the wire (`include[]`,
`timestamp_granularities[]`, `languages[]`, and the other documented array
fields). The overlay corrects those property names while retaining item types
and bounds. The generator's standard `nameOverrides` configuration keeps the
Swift part names simple, such as `.include`, while emitting `include[]` on the wire.
Upload encoding explicitly sets `application/octet-stream`;
the generator otherwise inferred `text/plain` from the source's legacy
`format: binary` annotation. Tests use OpenAPI Runtime's multipart decoder
to compare the generated fields and upload bytes with the curl requests.

The decoding tests reproduced the failures before these corrections. The
generated client now replays every capture offline, using the actual response
media types, including charset parameters. Streaming checks typed events,
reassembled text or PCM bytes, usage, and the final `[DONE]` marker.
Error bodies are replayed after serializing a valid request; the malformed
requests remain in `Requests/` for curl captures.
Unknown fields are accepted, while missing required diarized fields and unknown
stream event types are rejected. Additional-field and missing-field variants
exist only in test memory. No custom production decoder or manual generated
source change is used.

## Capture and test

```bash
export OPENAI_API_KEY=...  # Or load your existing credential environment.
python3 scripts/capture-api-fixtures.py audio
# Refresh only selected scenarios:
python3 scripts/capture-api-fixtures.py audio --case transcription-language-stream
swift test
```

Capture makes real, billable curl requests without retries. Multipart array
values become repeated bracketed fields. The `file` field refers to a saved
audio file relative to this folder. Authentication is passed over stdin and
headers are not saved. An unexpected status, media type, or missing terminal
event preserves the previous fixture.

Audio generation also enables voice and voice-consent operations. Creating
custom voices or consent recordings is not exercised by these captures.
Known-speaker reference uploads, other HTTP error statuses, Realtime audio,
and Chat/Responses audio are not covered here.
