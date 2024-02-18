import Dependencies
import Foundation
import HTTPTypes
import OpenAIUrlSessionClient
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

public struct OpenAIUrlSessionDependency {
    //    var fetch: @Sendable (Int) async throws -> String
    public var createChatCompletion: @Sendable (_ input: Operations.createChatCompletion.Input) async throws -> Operations
        .createChatCompletion.Output
}

extension OpenAIUrlSessionDependency: DependencyKey {
    public static var liveValue: Self {
        @Dependency(\.secrets) var secrets
        let client = Client(
            serverURL: URL(string: "https://api.openai.com/v1")!,
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware(apiKey: secrets.openAIKey())]
        )
        
        return Self(
            createChatCompletion: { try await client.createChatCompletion($0) }
        )
    }
}

extension DependencyValues {
    public var openAIUrlSession: OpenAIUrlSessionDependency {
        get { self[OpenAIUrlSessionDependency.self] }
        set { self[OpenAIUrlSessionDependency.self] = newValue }
    }
}

/// Injects an authorization header to every request.
struct AuthenticationMiddleware: ClientMiddleware {
    let apiKey: String
    
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields.append(.init(name: .authorization, value: "Bearer \(apiKey)"))
        
        return try await next(request, body, baseURL)
    }
}

public struct SecretsDependency: DependencyKey {
    public var openAIKey: @Sendable ()->String
    
    public init(openAIKey: @Sendable @escaping () -> String) {
        self.openAIKey = openAIKey
    }
    
    public static var liveValue: SecretsDependency {
        Self(openAIKey: {"bring your own key"})
    }
}

extension DependencyValues {
    public var secrets: SecretsDependency {
        get { self[SecretsDependency.self] }
        set { self[SecretsDependency.self] = newValue }
    }
}
