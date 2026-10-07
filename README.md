## Swift OpenAI API

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2Fswift-openai-api%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/atacan/swift-openai-api)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fatacan%2Fswift-openai-api%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/atacan/swift-openai-api)

This is a Swift package for the OpenAI public API. It is generated from the 
[official OpenAI OpenAPI specification](https://github.com/openai/openai-openapi) 
using [Swift OpenAPI Generator](https://swiftpackageindex.com/apple/swift-openapi-generator).

## Why not generate it yourself?

OpenAI's OpenAPI specification has some [issues](https://github.com/openai/openai-openapi/issues).
We transform `original_openapi.yaml` using the Python
[Swift OpenAPI Bootstrapper](https://github.com/atacan/swift-package-generator-based-on-openapi),
then apply [openapi-overlay.yaml](openapi-overlay.yaml). Run `make regenerate` to
rebuild the specification and Swift sources.

Regeneration uses the bootstrapper's nullable-first transformation pipeline and
requires [Speakeasy's OpenAPI CLI](https://github.com/speakeasy-api/openapi)
(`brew install openapi`) to apply overlays without corrupting Int64 bounds.

## Additions

- The server-sent-events response type for chat completions is now supported 
- The original API document has only 200 status documented as response. We add all the possible error responses with decodable error message payload, so that you can know what the error is.

## Usage

- `AuthenticationMiddleware` is provided to add API key authentication.
- Check out [Tests](/Tests)

### Chat Completions, Responses, and Audio fixtures

`swift test` runs offline using captured payloads in
[ChatCompletions](Tests/SwiftOpenaiApiTests/Resources/ChatCompletions) and
[Responses](Tests/SwiftOpenaiApiTests/Resources/Responses), and
[Audio](Tests/SwiftOpenaiApiTests/Resources/Audio), with separate test suites.
It checks JSON decoding and replays HTTP success and error responses through the
generated client. Chat streaming checks individual chunks, final usage, and
the `[DONE]` frame. Responses streaming checks typed events, text and function
argument deltas, reasoning items, and complete or incomplete terminal responses.
Audio checks speech binaries, JSON transcripts, text and subtitles, speaker
segments, and typed speech/transcription streams. Multipart requests are decoded
with OpenAPI Runtime to check field names, filenames, and exact upload bytes.

To deliberately refresh the fixtures, export `OPENAI_API_KEY` and run:

```bash
python3 scripts/capture-api-fixtures.py chat-completions
python3 scripts/capture-api-fixtures.py responses
python3 scripts/capture-api-fixtures.py audio
# Refresh just one scenario:
python3 scripts/capture-api-fixtures.py responses --case tool-call
```

This makes real, billable requests with curl. Requests, expected HTTP statuses,
and capture timestamps are saved alongside the unchanged response bodies.
The capture script preserves an existing fixture when the HTTP status or
content type differs from the expected result. See the
[Chat fixture notes](Tests/SwiftOpenaiApiTests/Resources/ChatCompletions/README.md),
[Responses fixture notes](Tests/SwiftOpenaiApiTests/Resources/Responses/README.md),
and [Audio fixture notes](Tests/SwiftOpenaiApiTests/Resources/Audio/README.md)
for the observed specification mismatches and coverage.

### Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/atacan/swift-openai-api", from: "0.1.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "OpenAIUrlSessionClient", package: "swift-openai-api"),
        // .product(name: "OpenAIAsyncHTTPClient", package: "swift-openai-api"),
    ]),
]
```

## Notes

### WebSocket

First incoming message is a `transcription_session.created` event.

```json
{
    "type": "transcription_session.created",
    "event_id": "event_BkolR18obdJWg4a3bKuhW",
    "session": {
        "id": "sess_BkolRXnnaIXV7cV3lu7Bv",
        "object": "realtime.transcription_session",
        "expires_at": 1750499725,
        "input_audio_noise_reduction": null,
        "turn_detection": {
            "type": "server_vad",
            "threshold": 0.5,
            "prefix_padding_ms": 300,
            "silence_duration_ms": 200
        },
        "input_audio_format": "pcm16",
        "input_audio_transcription": null,
        "client_secret": null,
        "include": null
    }
}
```

## RealtimeServerEvent.discriminator

Run the following to find the `type` value for each `RealtimeServerEvent` and use them to create the mapping in the `overlay.json`

```bash
yq '.components.schemas | .[] | select(key | test("RealtimeServerEvent.*")) | .properties.type.enum[]' openapi.yaml
```
