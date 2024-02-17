## Swift OpenAI API

This is a Swift package for the OpenAI public API. It is generated from the 
[official OpenAI OpenAPI specification](https://github.com/openai/openai-openapi) 
using [Swift OpenAPI Generator](https://swiftpackageindex.com/apple/swift-openapi-generator).

Additionally, it wraps the generated URLSession client to be used with [swift-dependencies](https://github.com/pointfreeco/swift-dependencies).
It does not hide the generated client or try to provide a more Swift-y or smaller API, so that we are able to use the full power of the OpenAPI generator.

### Installation

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/atacan/swift-openai-api", from: "0.1.0"),
],
targets: [
    .target(name: "YourTarget", dependencies: [
        .product(name: "OpenAIUrlSessionClient", package: "swift-openai-api"),
    ]),
]
```