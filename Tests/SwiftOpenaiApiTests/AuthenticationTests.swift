import Foundation
import HTTPTypes
import OpenAPIRuntime
import SwiftOpenaiApi
import Testing

struct AuthenticationTests {
    @Test(arguments: [("ApiKeyAuth", "createChatCompletion"), ("AdminApiKeyAuth", "admin-api-keys-list")])
    func selectsOperationCredential(scheme: String, operationID: String) async throws {
        let middleware = SwiftOpenaiApi.AuthenticationMiddleware(
            authentication: .credentials([
                "ApiKeyAuth": .init("regular-test-token"),
                "AdminApiKeyAuth": .init("admin-test-token"),
            ])
        )
        let expected = scheme == "ApiKeyAuth" ? "Bearer regular-test-token" : "Bearer admin-test-token"
        _ = try await middleware.intercept(
            HTTPRequest(method: .get, scheme: "https", authority: "offline.invalid", path: "/"),
            body: nil,
            baseURL: URL(string: "https://offline.invalid")!,
            operationID: operationID
        ) { request, body, url in
            #expect(request.headerFields[.authorization] == expected)
            return (HTTPResponse(status: .ok), nil)
        }
    }

    @Test func rejectsAmbiguousBearerShorthand() async throws {
        let middleware = SwiftOpenaiApi.AuthenticationMiddleware(authentication: .bearer("test-token"))
        await #expect(throws: AuthenticationError.self) {
            _ = try await middleware.intercept(
                HTTPRequest(method: .get, scheme: "https", authority: "offline.invalid", path: "/"),
                body: nil,
                baseURL: URL(string: "https://offline.invalid")!,
                operationID: "createChatCompletion"
            ) { _, _, _ in
                Issue.record("A missing named credential must stop the request")
                return (HTTPResponse(status: .ok), nil)
            }
        }
    }

    @Test func evaluatesDynamicCredentialsPerRequest() async throws {
        let provider = TokenProvider()
        let middleware = SwiftOpenaiApi.AuthenticationMiddleware(
            authentication: .credentials([
                "ApiKeyAuth": .init(provider: { await provider.next() })
            ])
        )
        for index in 1 ... 2 {
            _ = try await middleware.intercept(
                HTTPRequest(method: .get, scheme: "https", authority: "offline.invalid", path: "/"),
                body: nil,
                baseURL: URL(string: "https://offline.invalid")!,
                operationID: "createChatCompletion"
            ) { request, _, _ in
                #expect(request.headerFields[.authorization] == "Bearer test-token-\(index)")
                return (HTTPResponse(status: .ok), nil)
            }
        }
    }
}

private actor TokenProvider {
    private var count = 0
    func next() -> String {
        count += 1
        return "test-token-\(count)"
    }
}
