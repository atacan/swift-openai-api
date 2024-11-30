// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftOpenAIAPI",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)],
    products: [
        .library(name: "SwiftOpenAIAPI", targets: ["SwiftOpenAIAPI"]),
        // Products define the executables and libraries a package produces, making them visible to other packages.
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
        .target(name: "SwiftOpenAIAPI"),

        .target(
            name: "OpenAIUrlSessionClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            exclude: [
                "openapi.yaml",
                "openapi-generator-config.yaml",
            ]
        ),
        .target(
            name: "OpenAIAsyncHTTPClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIAsyncHTTPClient", package: "swift-openapi-async-http-client"),
            ],
            exclude: [
                "openapi.yaml",
                "openapi-generator-config.yaml",
            ]
        ),

        .testTarget(
            name: "SwiftOpenAIAPITests",
            dependencies: ["SwiftOpenAIAPI"]
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
