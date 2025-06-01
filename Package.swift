// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftOpenAIAPI",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)],
    products: [
        .library(name: "SwiftOpenAITypes", targets: ["SwiftOpenAITypes"]),
        .library(name: "OpenAIUrlSessionClient", targets: ["OpenAIUrlSessionClient"]),
        .library(name: "OpenAIAsyncHTTPClient", targets: ["OpenAIAsyncHTTPClient"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/swift-server/swift-openapi-async-http-client", from: "1.0.0"),
    ],
    targets: [
        .target(name: "SwiftOpenAITypes", dependencies: [
            .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
        ]),
        .target(
            name: "OpenAIUrlSessionClient",
            dependencies: [
                "SwiftOpenAITypes",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ]
        ),
        .target(
            name: "OpenAIAsyncHTTPClient",
            dependencies: [
                "SwiftOpenAITypes",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ],
            exclude: [
                "Documentation.docc",
            ]
        ),
        .testTarget(
            name: "OpenAIAsyncHTTPClientTests",
            dependencies: ["OpenAIAsyncHTTPClient"],
            resources: [
                .copy("Resources")
            ]
        ),
    ]
)
