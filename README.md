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
discriminator mapping inference (op14). It requires
[Speakeasy's OpenAPI CLI](https://github.com/speakeasy-api/openapi)
(`brew install openapi`) to apply overlays without corrupting Int64 bounds.

## Additions

- The server-sent-events response type for chat completions is now supported 
- The original API document has only 200 status documented as response. We add all the possible error responses with decodable error message payload, so that you can know what the error is.

## Usage

The package exposes five products: `SwiftOpenaiApiTypes` (HTTP models and API
protocol), `SwiftOpenaiApi` (transport-independent client and authentication),
`SwiftOpenaiApiURLSession`, `SwiftOpenaiApiAsyncHTTPClient`, and the separate
`SwiftOpenaiApiRealtimeTypes` WebSocket models.

Add the core product and your chosen convenience product to your target. Add
`SwiftOpenaiApiTypes` if you import models directly. Both factories return the
same `SwiftOpenaiApi.Client`:

```swift
import Foundation
import SwiftOpenaiApi
import SwiftOpenaiApiURLSession

let client = Client.urlSession(
    serverURL: URL(string: "https://api.openai.com/v1")!,
    authentication: .credentials(["ApiKeyAuth": .init("YOUR_API_KEY")])
)
```

```swift
import Foundation
import SwiftOpenaiApi
import SwiftOpenaiApiAsyncHTTPClient

let client = Client.asyncHTTPClient(
    serverURL: URL(string: "https://api.openai.com/v1")!,
    authentication: .credentials(["ApiKeyAuth": .init("YOUR_API_KEY")])
)
```

The final specification declares two bearer schemes: ordinary requests use
`ApiKeyAuth`; administration operations use `AdminApiKeyAuth`. Supply named
credentials for the operations you call. `.bearer(...)` requires exactly one
bearer scheme and therefore cannot select between these schemes. Dynamic tokens
use `.credentials(["ApiKeyAuth": .init(provider: { try await tokenStore.token() })])`.
Providers run per request; your application handles token acquisition and refresh.
Missing credentials cause an authentication error before the request is sent.

Both factories accept `configuration:`, `transportConfiguration:`, and
`middlewares:`. Extra middleware runs before shared authentication. Use the
core initializer `Client(serverURL:configuration:transport:authentication:middlewares:)`
for your own transport. The original generated initializer with `transport:` and
`middlewares:` remains available for custom authentication. The deprecated
`SwiftOpenaiApiTypes.AuthenticationMiddleware(apiKey:)` remains available for
existing callers; new code uses shared authentication from `SwiftOpenaiApi`.

The default transports use their shared session/client. When injecting a session
or HTTP client through the upstream transport configuration, declare and import
the upstream transport product directly. Your application owns its lifecycle;
do not invalidate the shared session or shut down the shared HTTP client.
Transport packages are declared at package level even when using only core.

Factory helpers and shared authentication are preserved by regeneration;
`Authentication/GeneratedSecurity/OperationSecurity.swift` is regenerated from
the final overlaid specification. Keep custom edits outside `GeneratedSources/`.
Check out [Tests](/Tests).

### Realtime WebSocket types

Add the independently importable `SwiftOpenaiApiRealtimeTypes` product to your target:

```swift
.product(name: "SwiftOpenaiApiRealtimeTypes", package: "swift-openai-api")
```

The library provides public `Codable` types under `Components.Schemas` for
encoding client events and decoding server events:

```swift
import Foundation
import SwiftOpenaiApiRealtimeTypes

let event = Components.Schemas.RealtimeClientEventInputAudioBufferAppend(
    _type: .input_audio_buffer_period_append,
    audio: Data([1, 2, 3]).base64EncodedString()
)
let message = try JSONEncoder().encode(event)

// Decode an incoming JSON WebSocket message:
let serverEvent = try JSONDecoder().decode(
    Components.Schemas.RealtimeServerEvent.self,
    from: incomingMessage
)
```

When importing both types libraries, qualify the namespace as
`SwiftOpenaiApiRealtimeTypes.Components.Schemas` to distinguish it from the HTTP types.
WebSocket connection handling is supplied by your application.

[openapi-generator-config-realtime.yaml](openapi-generator-config-realtime.yaml)
hardcodes four root schemas: `RealtimeClientEventTranscriptionSessionUpdate`,
`RealtimeClientEventInputAudioBufferAppend`,
`RealtimeServerEventConversationItemInputAudioTranscriptionCompleted`, and
`RealtimeServerEvent`. The generator's native `filter.schemas` includes their
referenced dependencies, including all variants of `RealtimeServerEvent`, with zero paths.
To add another root schema, extend that configuration's `schemas` list.

```bash
make generate-realtime # Generate only realtime types from the transformed openapi.yaml
make generate          # Generate HTTP types, the HTTP client, and realtime types
make regenerate        # Transform the original specification, apply overlays, and generate all targets
```

`swift test --filter RealtimeTypesTests` runs the offline [realtime tests](Tests/SwiftOpenaiApiRealtimeTypesTests).

### Chat Completions, Responses, and Audio fixtures

Run the offline suites explicitly:

```bash
swift test --filter 'ChatCompletionsTests|ResponsesTests|AudioTests|RealtimeTypesTests|URLSessionFactoryTests|AsyncHTTPClientFactoryTests|AuthenticationTests|SwiftOpenaiApiTypesTests'
```

These suites use captured payloads in
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
    .package(url: "https://github.com/atacan/swift-openai-api", from: "5.0.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "SwiftOpenaiApi", package: "swift-openai-api"),
        .product(name: "SwiftOpenaiApiURLSession", package: "swift-openai-api"),
        // Or: .product(name: "SwiftOpenaiApiAsyncHTTPClient", package: "swift-openai-api"),
        // Add SwiftOpenaiApiTypes when importing models directly.
    ]),
]
```

## Troubleshooting response decoding

The current schemas represent timestamps as numbers, so factories use the runtime's
standard configuration. For future schemas with fractional ISO 8601 timestamps,
`Expected date string to be ISO8601-formatted` can require
`configuration: .init(dateTranscoder: .iso8601WithFractionalSeconds)`. Set a
provider default in both factory helpers only after confirming the actual response
format, and retain explicit configuration overrides. A standalone `JSONDecoder`
still requires its own `dateDecodingStrategy`.

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

The Python bootstrapper infers `RealtimeServerEvent` discriminator mappings from
the variants' required `type` enums, so the generated enum decodes event names such
as `conversation.item.input_audio_transcription.completed`. New variants with
distinct, required tag values are mapped automatically during regeneration.
