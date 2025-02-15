#if os(Linux)
@preconcurrency import struct Foundation.URL
@preconcurrency import struct Foundation.Data
@preconcurrency import struct Foundation.Date
#else
import struct Foundation.URL
import struct Foundation.Data
import struct Foundation.Date
#endif
import AsyncHTTPClient
import HTTPTypes
import OpenAPIRuntime


/// Injects an authorization header to every request.
public struct AuthenticationMiddleware: ClientMiddleware {
    /// The token value.
    private let token: String
    private let authenticationType: AuthenticationType
    
    public init(token: String, type: AuthenticationType = .bearer) {
        self.token = token
        self.authenticationType = type
    }

    public init(bearerToken: String) {
        self.token = bearerToken
        self.authenticationType = .bearer
    }
    
    /// Authentication type to determine how the token should be formatted
    public enum AuthenticationType: Sendable {
        case bearer
        case apiKey

        var valuePrefix: String {
            switch self {
            case .bearer:
                return "Bearer "
            case .apiKey:
                return ""
            }
        }
    }

    public func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = authenticationType.valuePrefix + token
        return try await next(request, body, baseURL)
    }
}