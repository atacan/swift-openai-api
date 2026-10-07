import Foundation
import HTTPTypes
import OpenAPIRuntime
import SwiftOpenaiApi
import SwiftOpenaiApiTypes
import Testing

struct ChatCompletionsTests {
    @Test(arguments: ["responseChatCompletion", "text", "tool-call", "logprobs"])
    func decodesChatCompletion(name: String) throws {
        let payload = try fixture(name)
        let completion = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: payload)
        #expect(completion.object == .chat_period_completion)
        #expect(!completion.id.isEmpty)
        #expect(!completion.model.isEmpty)
        #expect(completion.created > 0)
        #expect(!completion.choices.isEmpty)
        #expect(completion.choices.first?.message.role == .assistant)
        let usage = try #require(completion.usage)
        #expect(usage.total_tokens == usage.prompt_tokens + usage.completion_tokens)
        if name != "logprobs" {
            #expect(completion.choices.first?.logprobs == nil)
            #expect(usage.prompt_tokens_details?.cache_write_tokens == 0)
        }
    }

    @Test(arguments: ["missing-messages", "unsupported-reasoning", "unknown-model", "unauthenticated"])
    func decodesError(name: String) throws {
        let error = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: fixture(name)).error
        #expect(!error.message.isEmpty)
        #expect(!error._type.isEmpty)
        switch name {
        case "missing-messages":
            #expect(error.code == "missing_required_parameter")
            #expect(error.param == "messages")
        case "unsupported-reasoning":
            #expect(error.code == nil)
            #expect(error.param == "reasoning_effort")
        case "unknown-model":
            #expect(error.code == "model_not_found")
            #expect(error.param == nil)
        case "unauthenticated":
            #expect(error.code == nil)
            #expect(error.param == nil)
        default: Issue.record("Unexpected error fixture: \(name)")
        }
    }

    @Test func decodesFunctionCall() throws {
        let completion = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: fixture("tool-call"))
        let choice = try #require(completion.choices.first)
        #expect(choice.finish_reason == .tool_calls)
        #expect(choice.message.content == nil)
        let call = try #require(choice.message.tool_calls?.first)
        guard case .function(let functionCall) = call else {
            Issue.record("Expected the function discriminator to select a function tool call")
            return
        }
        #expect(functionCall.function.name == "get_weather")
        struct Arguments: Decodable { let city: String }
        let arguments = try JSONDecoder().decode(Arguments.self, from: Data(functionCall.function.arguments.utf8))
        #expect(arguments.city == "Berlin")
    }

    @Test func decodesLogprobDetails() throws {
        let completion = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: fixture("logprobs"))
        let choice = try #require(completion.choices.first)
        let logprobs = try #require(choice.logprobs)
        #expect(logprobs.refusal == nil)
        let tokens = try #require(logprobs.content)
        #expect(!tokens.isEmpty)
        #expect(tokens.map(\.token).joined() == choice.message.content)
        #expect(tokens.allSatisfy { !$0.top_logprobs.isEmpty })
    }

    @Test func decodesExplicitNullLogprobs() throws {
        let payload = try fixture("text")
        let expected = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: payload)
        var object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        var choices = try #require(object["choices"] as? [[String: Any]])
        choices[0]["logprobs"] = NSNull()
        object["choices"] = choices
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: modified) == expected)
    }

    @Test func ignoresAdditionalResponseFields() throws {
        let payload = try fixture("text")
        let expected = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: payload)
        var object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["future_response_field"] = ["enabled": true]
        var choices = try #require(object["choices"] as? [[String: Any]])
        var message = try #require(choices[0]["message"] as? [String: Any])
        message["future_message_field"] = [1, 2, 3]
        choices[0]["message"] = message
        object["choices"] = choices
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: modified) == expected)
    }

    @Test(arguments: ["id", "choices", "created", "model", "object"])
    func stillRejectsMissingRequiredResponseFields(field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("text")) as? [String: Any])
        object.removeValue(forKey: field)
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: modified)
        }
    }

    @Test(arguments: [
        ("text", 200), ("tool-call", 200), ("logprobs", 200),
        ("missing-messages", 400), ("unsupported-reasoning", 400),
        ("unknown-model", 404), ("unauthenticated", 401),
    ])
    func generatedClientDecodesResponse(name: String, status: Int) async throws {
        let payload = try fixture(name)
        let response = try await replay(payload: payload, status: status, requestName: status == 200 ? name : "text")
        if status == 200 {
            let expected = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionResponse.self, from: payload)
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

    @Test func decodesStreamThroughGeneratedClient() async throws {
        let payload = try fixture("stream", extension: "sse")
        let response = try await replay(payload: payload, status: 200, contentType: "text/event-stream", requestName: "stream")
        let body = try response.ok.body.text_event_hyphen_stream
        var chunks: [Components.Schemas.CreateChatCompletionStreamResponse] = []
        var receivedDone = false
        for try await event in body.asDecodedServerSentEvents() {
            let data = try #require(event.data)
            if data == "[DONE]" {
                receivedDone = true
                break
            }
            let chunk = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionStreamResponse.self, from: Data(data.utf8))
            #expect(chunk.object == .chat_period_completion_period_chunk)
            chunks.append(chunk)
        }
        #expect(receivedDone)
        #expect(chunks.count > 1)
        #expect(chunks.first?.choices.first?.delta.role == .assistant)
        #expect(chunks.flatMap(\.choices).contains { $0.finish_reason == .stop })
        #expect(chunks.compactMap(\.usage).count == 1)
        #expect(chunks.last?.choices.isEmpty == true)
        #expect(chunks.flatMap(\.choices).compactMap(\.delta.content).joined() == "Hello.")
    }

    private func replay(payload: Data, status: Int, contentType: String = "application/json", requestName: String = "text") async throws -> Operations.createChatCompletion.Output {
        let requestPayload = try fixture("Requests/\(requestName)")
        let client = Client(
            serverURL: try Servers.Server1.url(),
            transport: FixtureTransport(payload: payload, status: status, contentType: contentType, expectedRequest: requestPayload)
        )
        // Even error fixtures use a valid request here: this test exercises response decoding.
        let request = try JSONDecoder().decode(Components.Schemas.CreateChatCompletionRequest.self, from: requestPayload)
        return try await client.createChatCompletion(body: .json(request))
    }
}

private func fixture(_ name: String, extension fileExtension: String = "json") throws -> Data {
    let directory = "Resources/ChatCompletions"
    let url = try #require(Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: directory))
    return try Data(contentsOf: url)
}

private struct FixtureTransport: ClientTransport {
    let payload: Data
    let status: Int
    let contentType: String
    let expectedRequest: Data

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(request.method == .post)
        #expect(request.path == "/chat/completions")
        #expect(baseURL.absoluteString == "https://api.openai.com/v1")
        #expect(operationID == Operations.createChatCompletion.id)
        let requestBody = try #require(body)
        let requestData = try await Data(collecting: requestBody, upTo: 16 * 1024)
        let actual = try #require(JSONSerialization.jsonObject(with: requestData) as? NSDictionary)
        let expected = try #require(JSONSerialization.jsonObject(with: expectedRequest) as? NSDictionary)
        #expect(actual == expected)
        let response = HTTPResponse(status: .init(code: status), headerFields: [.contentType: contentType])
        return (response, HTTPBody(payload))
    }
}
