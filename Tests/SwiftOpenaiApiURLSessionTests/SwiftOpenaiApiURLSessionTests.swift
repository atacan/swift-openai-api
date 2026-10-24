import Foundation
import HTTPTypes
import OpenAPIRuntime
import SwiftOpenaiApi
import SwiftOpenaiApiTypes
import SwiftOpenaiApiURLSession
import Testing

/// All responses are supplied by middleware; these tests never open a connection.
struct URLSessionFactoryTests {
    @Test(arguments: [false, true])
    func decodesResponseAndForwardsConfiguration(overrideConfiguration: Bool) async throws {
        let middleware = OfflineResponseMiddleware(expectPrettyPrinted: !overrideConfiguration)
        let client: Client
        if overrideConfiguration {
            client = .urlSession(
                serverURL: URL(string: "https://offline.invalid/v1")!,
                authentication: .credentials(["ApiKeyAuth": .init("test-token")]),
                configuration: .init(jsonEncodingOptions: []),
                middlewares: [middleware]
            )
        } else {
            client = .urlSession(
                serverURL: URL(string: "https://offline.invalid/v1")!,
                authentication: .credentials(["ApiKeyAuth": .init("test-token")]),
                middlewares: [middleware]
            )
        }
        let request = try JSONDecoder()
            .decode(
                Components.Schemas.CreateChatCompletionRequest.self,
                from: Data(#"{"model":"test-model","messages":[{"role":"user","content":"Hello"}]}"#.utf8)
            )
        let response = try await client.createChatCompletion(body: .json(request))
        let completion = try response.ok.body.json
        #expect(completion.id == "offline-completion")
        #expect(completion.created == 1_791_368_205)
        #expect(completion.choices.first?.message.content == "Hello.")
    }

    @Test func requiresNamedCredentialsBeforeSending() async throws {
        let client = Client.urlSession(serverURL: URL(string: "https://offline.invalid/v1")!)
        let request = try JSONDecoder()
            .decode(
                Components.Schemas.CreateChatCompletionRequest.self,
                from: Data(#"{"model":"test-model","messages":[{"role":"user","content":"Hello"}]}"#.utf8)
            )
        do {
            _ = try await client.createChatCompletion(body: .json(request))
            Issue.record("Expected missing credentials to stop the request")
        } catch let error as ClientError {
            guard case AuthenticationError.unsatisfiedSecurityRequirements(let operationID) = error.underlyingError else {
                Issue.record("Expected an authentication error before transport invocation")
                return
            }
            #expect(operationID == Operations.createChatCompletion.id)
        }
    }
}

private struct OfflineResponseMiddleware: ClientMiddleware {
    let expectPrettyPrinted: Bool

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(baseURL.absoluteString == "https://offline.invalid/v1")
        #expect(request.path == "/chat/completions")
        #expect(operationID == Operations.createChatCompletion.id)
        let body = try #require(body)
        let requestBytes = try await Data(collecting: body, upTo: 16 * 1024)
        #expect(String(decoding: requestBytes, as: UTF8.self).contains("\n") == expectPrettyPrinted)
        let payload =
            #"{"id":"offline-completion","object":"chat.completion","created":1791368205,"model":"test-model","choices":[{"index":0,"message":{"role":"assistant","content":"Hello."},"finish_reason":"stop"}]}"#
        return (HTTPResponse(status: .ok, headerFields: [.contentType: "application/json"]), HTTPBody(payload))
    }
}
