//
// https://github.com/atacan
// 17.02.24


import SwiftUI
import OpenAIUrlSessionClient
import OpenAPIRuntime
import OpenAPIURLSession
import Foundation
import HTTPTypes
import Dependencies


public struct OpenAIUrlSessionDependency {
    //    var fetch: @Sendable (Int) async throws -> String
    var createChatCompletion: @Sendable (_ input: Operations.createChatCompletion.Input) async throws -> Operations.createChatCompletion.Output
}

extension OpenAIUrlSessionDependency: DependencyKey {
    public static var liveValue: Self {
        let client = Client(serverURL: URL(string: "https://api.openai.com/v1")!, transport: URLSessionTransport(), middlewares: [AuthenticationMiddleware(apiKey: "sk-")])
        
        return Self(
            createChatCompletion: {try await client.createChatCompletion($0)}
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
    
    func intercept(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String, next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields.append(.init(name: .authorization, value: "Bearer \(apiKey)"))
        
        return try await next(request, body, baseURL)
    }
    
}
