// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftOpenAIAPI",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(name: "SwiftOpenAIAPI", targets: ["SwiftOpenAIAPI"]),
        
        .library(name: "OpenAIUrlSessionClient", targets: ["OpenAIUrlSessionClient"]),
        .library(name: "OpenAIUrlSessionDependency", targets: ["OpenAIUrlSessionDependency"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-openapi-generator", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-runtime", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession", from: "1.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(name: "SwiftOpenAIAPI"),
        
        .target(
            name: "OpenAIUrlSessionClient",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
            ],
            plugins: [.plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")]
        ),
        .target(name: "OpenAIUrlSessionDependency", dependencies: [
           "OpenAIUrlSessionClient",
           .product(name: "Dependencies", package: "swift-dependencies"),
        ]),
        .testTarget(
            name: "SwiftOpenAIAPITests",
            dependencies: ["SwiftOpenAIAPI"]),
    ]
)
