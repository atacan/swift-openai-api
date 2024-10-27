## Swift OpenAI API

This is a Swift package for the OpenAI public API. It is generated from the 
[official OpenAI OpenAPI specification](https://github.com/openai/openai-openapi) 
using [Swift OpenAPI Generator](https://swiftpackageindex.com/apple/swift-openapi-generator).

## Issues

OpenAI's OpenAPI specification has some issues. Some of them are fixed in the download script with string replacements.

For example, duplicate models are removed from the OpenAPI specification. Type mismatches are fixed by replacing the type with the correct one.

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