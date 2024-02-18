import Foundation
import HTTPTypes
import OpenAIUrlSessionClient
import OpenAPIRuntime
import OpenAPIURLSession
import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
        .task {
            try? await HelloWorldURLSessionClient().check()
        }
    }
}

#Preview {
    ContentView()
}

public struct HelloWorldURLSessionClient {
    public init() {}
    public func check() async throws {
        let client = Client(
            serverURL: URL(string: "https://api.openai.com/v1")!,
            transport: URLSessionTransport(),
            middlewares: [AuthenticationMiddleware()]
        )

        let output = try await client.createChatCompletion(
            .init(
                body: .json(
                    .init(
                        messages: [
                            .ChatCompletionRequestSystemMessage(
                                .init(content: "Just say your name.", role: .system)
                            ),
                            .ChatCompletionRequestUserMessage(.init(content: .case1("Nice to meet you."), role: .user))
                        ],
                        model: .init(value2: .gpt_hyphen_3_period_5_hyphen_turbo),
                        stream: true
                    )
                )
            )
        )
        print(output)
    }
}

/// For example, to implement a middleware that injects the "Authorization"
/// header to every outgoing request, define a new struct that conforms to
/// the `ClientMiddleware` protocol:
///
/// Injects an authorization header to every request.
struct AuthenticationMiddleware: ClientMiddleware {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields.append(.init(name: .authorization, value: "Bearer sk-_____"))

        return try await next(request, body, baseURL)
    }
}
