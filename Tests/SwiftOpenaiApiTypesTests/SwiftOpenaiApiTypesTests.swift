import Foundation
import SwiftOpenaiApiTypes
import Testing

struct SwiftOpenaiApiTypesTests {
    @Test func typesProductDecodesWithoutClientOrTransportImports() throws {
        let payload = Data(#"{"error":{"message":"Offline error","type":"invalid_request_error","param":null,"code":null}}"#.utf8)
        let response = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: payload)
        #expect(response.error.message == "Offline error")
    }
}
