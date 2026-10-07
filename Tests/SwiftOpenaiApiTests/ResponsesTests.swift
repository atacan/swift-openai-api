import Foundation
import HTTPTypes
import OpenAPIRuntime
import SwiftOpenaiApi
import SwiftOpenaiApiTypes
import Testing

struct ResponsesTests {
    @Test(arguments: ["text", "tool-call", "tool-result", "structured-output", "reasoning", "incomplete", "logprobs"])
    func decodesResponse(name: String) throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture(name))
        #expect(response.value3.object == .response)
        #expect(!response.value3.id.isEmpty)
        #expect(!response.value3.output.isEmpty)
        #expect(response.value3.error == nil)
        #expect(response.value3.status == (name == "incomplete" ? .incomplete : .completed))
        let usage = try #require(response.value3.usage)
        #expect(usage.total_tokens == usage.input_tokens + usage.output_tokens)
    }

    @Test(arguments: [
        "text", "tool-call", "tool-result", "structured-output", "reasoning", "incomplete", "logprobs", "stream", "tool-call-stream", "incomplete-stream", "reasoning-stream",
    ])
    func decodesRequest(name: String) throws {
        _ = try JSONDecoder().decode(Components.Schemas.CreateResponse.self, from: fixture("Requests/\(name)"))
    }

    @Test func decodesFunctionCallAndResult() throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("tool-call"))
        let item = try #require(response.value3.output.first)
        guard case .function_call(let call) = item else {
            Issue.record("Expected a function call output item")
            return
        }
        #expect(call.name == "get_weather")
        #expect(call.status == .completed)
        struct Arguments: Decodable { let city: String }
        #expect(try JSONDecoder().decode(Arguments.self, from: Data(call.arguments.utf8)).city == "Berlin")

        let request = try JSONDecoder().decode(Components.Schemas.CreateResponse.self, from: fixture("Requests/tool-result"))
        guard case .case2(let items) = try #require(request.value3.input),
            items.count == 3,
            case .EasyInputMessage(let message) = items[0],
            case .Item(.FunctionToolCall(let inputCall)) = items[1],
            case .Item(.FunctionCallOutputItemParam(let result)) = items[2]
        else {
            Issue.record("Expected a message without type, a previous call, and its result")
            return
        }
        #expect(message._type == nil)
        #expect(inputCall.name == "get_weather")
        #expect(result.call_id == inputCall.call_id)
        let completed = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("tool-result"))
        #expect(outputText(completed).contains("20"))
    }

    @Test func decodesStructuredOutput() throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("structured-output"))
        struct Weather: Decodable {
            let city: String
            let temperatureC: Int
            enum CodingKeys: String, CodingKey {
                case city
                case temperatureC = "temperature_c"
            }
        }
        let weather = try JSONDecoder().decode(Weather.self, from: Data(outputText(response).utf8))
        #expect(weather.city == "Berlin")
        #expect(weather.temperatureC == 20)
    }

    @Test func decodesReasoning() throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("reasoning"))
        let item = try #require(response.value3.output.first)
        guard case .reasoning(let reasoning) = item else {
            Issue.record("Expected a reasoning output item")
            return
        }
        #expect(!reasoning.id.isEmpty)
        #expect(try #require(reasoning.encrypted_content).isEmpty == false)
        #expect(try #require(response.value3.usage).output_tokens_details.reasoning_tokens > 0)
        #expect(!outputText(response).isEmpty)
    }

    @Test func decodesIncompleteResponse() throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("incomplete"))
        #expect(response.value3.status == .incomplete)
        #expect(response.value3.incomplete_details?.reason == .max_output_tokens)
        #expect(response.value3.completed_at == nil)
        #expect(try #require(response.value3.usage).output_tokens == response.value3.max_output_tokens)
        guard case .message(let message) = try #require(response.value3.output.first) else {
            Issue.record("Expected an incomplete assistant message")
            return
        }
        #expect(message.status == .incomplete)
    }

    @Test func decodesLogprobs() throws {
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: fixture("logprobs"))
        guard case .message(let message) = try #require(response.value3.output.first),
            case .output_text(let content) = try #require(message.content.first)
        else {
            Issue.record("Expected output text with token probabilities")
            return
        }
        #expect(!content.logprobs.isEmpty)
        #expect(content.logprobs.map(\.token).joined() == content.text)
        #expect(content.logprobs.allSatisfy { !$0.top_logprobs.isEmpty })
    }

    @Test func acceptsOmittedErrorAndAdditionalFields() throws {
        let payload = try fixture("text")
        let expected = try JSONDecoder().decode(Components.Schemas.Response.self, from: payload)
        var object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(object["error"] is NSNull)
        object.removeValue(forKey: "error")
        object["future_response_field"] = ["enabled": true]
        var output = try #require(object["output"] as? [[String: Any]])
        output[0]["future_item_field"] = [1, 2, 3]
        object["output"] = output
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(Components.Schemas.Response.self, from: modified) == expected)
    }

    @Test func decodesNonNullGenerationError() throws {
        // An in-memory schema regression; the saved fixtures remain real API bodies.
        var object = try #require(JSONSerialization.jsonObject(with: fixture("text")) as? [String: Any])
        object["status"] = "failed"
        object["error"] = ["code": "server_error", "message": "Fixture generation error"]
        let modified = try JSONSerialization.data(withJSONObject: object)
        let response = try JSONDecoder().decode(Components.Schemas.Response.self, from: modified)
        #expect(response.value3.status == .failed)
        #expect(response.value3.error?.code == .server_error)
        #expect(response.value3.error?.message == "Fixture generation error")
    }

    @Test(arguments: ["id", "role", "content", "status"])
    func stillRejectsMissingRequiredMessageFields(field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("text")) as? [String: Any])
        var output = try #require(object["output"] as? [[String: Any]])
        output[0].removeValue(forKey: field)
        object["output"] = output
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.Response.self, from: modified)
        }
    }

    @Test func rejectsUnknownOutputItemType() throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("text")) as? [String: Any])
        var output = try #require(object["output"] as? [[String: Any]])
        output[0]["type"] = "unknown_output_item_type"
        object["output"] = output
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.Response.self, from: modified)
        }
    }

    @Test(arguments: ["id", "object", "created_at", "output", "parallel_tool_calls"])
    func stillRejectsMissingRequiredResponseFields(field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("text")) as? [String: Any])
        object.removeValue(forKey: field)
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.Response.self, from: modified)
        }
    }

    @Test(arguments: ["missing-model", "invalid-max-output-tokens", "unknown-model", "unauthenticated"])
    func decodesError(name: String) throws {
        let error = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: fixture(name)).error
        #expect(!error.message.isEmpty)
        #expect(error._type == "invalid_request_error")
        switch name {
        case "missing-model":
            #expect(error.code == "missing_required_parameter")
            #expect(error.param == "model")
        case "invalid-max-output-tokens":
            #expect(error.code == "integer_below_min_value")
            #expect(error.param == "max_output_tokens")
        case "unknown-model":
            #expect(error.code == "model_not_found")
            #expect(error.param == nil)
        case "unauthenticated":
            #expect(error.code == nil)
            #expect(error.param == nil)
        default: Issue.record("Unexpected error fixture: \(name)")
        }
    }

    @Test(arguments: [
        ("text", 200), ("tool-call", 200), ("tool-result", 200), ("structured-output", 200),
        ("reasoning", 200), ("incomplete", 200), ("logprobs", 200),
        ("missing-model", 400), ("invalid-max-output-tokens", 400),
        ("unknown-model", 404), ("unauthenticated", 401),
    ])
    func generatedClientDecodesResponse(name: String, status: Int) async throws {
        let payload = try fixture(name)
        let response = try await replay(payload: payload, status: status, requestName: status == 200 ? name : "text")
        if status == 200 {
            let expected = try JSONDecoder().decode(Components.Schemas.Response.self, from: payload)
            #expect(try response.ok.body.json == expected)
        } else {
            let expected = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: payload)
            switch status {
            case 400: #expect(try response.badRequest.body.json == expected)
            case 401: #expect(try response.unauthorized.body.json == expected)
            case 404: #expect(try response.notFound.body.json == expected)
            default: Issue.record("Unexpected fixture status: \(status)")
            }
        }
    }

    @Test(arguments: ["stream", "tool-call-stream", "incomplete-stream", "reasoning-stream"])
    func decodesStreamThroughGeneratedClient(name: String) async throws {
        let response = try await replay(payload: fixture(name, extension: "sse"), status: 200, contentType: "text/event-stream", requestName: name)
        let body = try response.ok.body.text_event_hyphen_stream
        var count = 0
        var text = ""
        var arguments = ""
        var finishedItems: [Components.Schemas.OutputItem] = []
        var terminal: Components.Schemas.Response?
        var receivedCreated = false
        var receivedInProgress = false
        for try await event in body.asDecodedServerSentEvents() {
            let data = try #require(event.data)
            let raw = Data(data.utf8)
            let object = try #require(JSONSerialization.jsonObject(with: raw) as? [String: Any])
            #expect(event.event == object["type"] as? String)
            #expect(object["sequence_number"] as? Int == count)
            #expect(terminal == nil)
            let decoded = try JSONDecoder().decode(Components.Schemas.ResponseStreamEvent.self, from: raw)
            switch decoded {
            case .response_period_created(let value):
                receivedCreated = true
                #expect(value.response.value3.status == .in_progress)
                #expect(value.response.value3.error == nil)
                #expect(value.response.value3.usage == nil)
            case .response_period_in_progress(let value):
                receivedInProgress = true
                #expect(value.response.value3.status == .in_progress)
            case .response_period_output_text_period_delta(let value): text += value.delta
            case .response_period_output_text_period_done(let value): #expect(value.text == text)
            case .response_period_function_call_arguments_period_delta(let value): arguments += value.delta
            case .response_period_function_call_arguments_period_done(let value): #expect(value.arguments == arguments)
            case .response_period_output_item_period_done(let value): finishedItems.append(value.item)
            case .response_period_completed(let value): terminal = value.response
            case .response_period_incomplete(let value): terminal = value.response
            case .response_period_output_item_period_added, .response_period_content_part_period_added, .response_period_content_part_period_done:
                break
            default: Issue.record("Unexpected event in \(name): \(event.event ?? "unknown")")
            }
            count += 1
        }
        #expect(count > 1)
        #expect(receivedCreated && receivedInProgress)
        let final = try #require(terminal)
        #expect(final.value3.error == nil)
        #expect(final.value3.output.count == finishedItems.count)
        for (finalItem, streamedItem) in zip(final.value3.output, finishedItems) {
            if case .reasoning(let finalReasoning) = finalItem,
                case .reasoning(let streamedReasoning) = streamedItem
            {
                // The capture has different opaque ciphertext in item.done and
                // response.completed. Compare the reasoning fields we can inspect.
                #expect(finalReasoning.id == streamedReasoning.id)
                #expect(finalReasoning.summary == streamedReasoning.summary)
                #expect(finalReasoning.content == streamedReasoning.content)
                #expect(finalReasoning.status == streamedReasoning.status)
                #expect(try #require(finalReasoning.encrypted_content).isEmpty == false)
                #expect(try #require(streamedReasoning.encrypted_content).isEmpty == false)
            } else {
                #expect(finalItem == streamedItem)
            }
        }
        #expect(final.value3.status == (name == "incomplete-stream" ? .incomplete : .completed))
        let usage = try #require(final.value3.usage)
        #expect(usage.total_tokens == usage.input_tokens + usage.output_tokens)
        if name == "tool-call-stream" {
            guard case .function_call(let call) = try #require(final.value3.output.first) else {
                Issue.record("Expected the final response to contain the streamed function call")
                return
            }
            #expect(call.arguments == arguments)
            #expect(call.name == "get_weather")
        } else {
            #expect(outputText(final) == text)
            #expect(!text.isEmpty)
        }
        if name == "stream" { #expect(text == "Hello.") }
        if name == "incomplete-stream" { #expect(final.value3.incomplete_details?.reason == .max_output_tokens) }
        if name == "reasoning-stream" { #expect(usage.output_tokens_details.reasoning_tokens > 0) }
    }

    private func replay(payload: Data, status: Int, contentType: String = "application/json", requestName: String) async throws -> Operations.createResponse.Output {
        let requestPayload = try fixture("Requests/\(requestName)")
        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: ResponsesFixtureTransport(payload: payload, status: status, contentType: contentType, expectedRequest: requestPayload)
        )
        let request = try JSONDecoder().decode(Components.Schemas.CreateResponse.self, from: requestPayload)
        return try await client.createResponse(body: .json(request))
    }

    private func outputText(_ response: Components.Schemas.Response) -> String {
        response.value3.output
            .compactMap { item -> String? in
                guard case .message(let message) = item else { return nil }
                return message.content
                    .compactMap { content -> String? in
                        guard case .output_text(let text) = content else { return nil }
                        return text.text
                    }
                    .joined()
            }
            .joined()
    }
}

private func fixture(_ name: String, extension fileExtension: String = "json") throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Resources/Responses"))
    return try Data(contentsOf: url)
}

private struct ResponsesFixtureTransport: ClientTransport {
    let payload: Data
    let status: Int
    let contentType: String
    let expectedRequest: Data

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(request.method == .post)
        #expect(request.path == "/responses")
        #expect(baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(operationID == Operations.createResponse.id)
        let requestBody = try #require(body)
        let requestData = try await Data(collecting: requestBody, upTo: 64 * 1024)
        let actual = try #require(JSONSerialization.jsonObject(with: requestData) as? NSDictionary)
        let expected = try #require(JSONSerialization.jsonObject(with: expectedRequest) as? NSDictionary)
        #expect(actual == expected)
        let response = HTTPResponse(status: .init(code: status), headerFields: [.contentType: contentType])
        return (response, HTTPBody(payload))
    }
}
