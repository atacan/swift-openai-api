## Swift OpenAI API

This is a Swift package for the OpenAI public API. It is generated from the 
[official OpenAI OpenAPI specification](https://github.com/openai/openai-openapi) 
using [Swift OpenAPI Generator](https://swiftpackageindex.com/apple/swift-openapi-generator).

## Why not generate it yourself?

OpenAI's OpenAPI specification has some [issues](https://github.com/openai/openai-openapi/issues). Some of them are fixed in the [download script](/scripts/openaiYamlDownload.swift) with string replacements.

For example, duplicate models are removed, type mismatches are fixed.

## Additions

- The server-sent-events response type for chat completions is now supported 
- The original API document has only 200 status documented as response. We add all the possible error responses with decodable error message payload, so that you can know what the error is.

## Usage

- `AuthenticationMiddleware` is provided to add API key authentication.
- Check out [Tests](/Tests)

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