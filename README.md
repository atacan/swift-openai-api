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
