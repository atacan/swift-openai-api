import Testing
@testable import OpenAIAsyncHTTPClient

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
import OpenAPIAsyncHTTPClient
import Foundation

struct OpenAIAsyncHTTPClientTest {

    let client = {
        // get api key from environment value OPENAI_API_KEY
        let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"]!

        let authMiddleware = AuthenticationMiddleware(bearerToken: apiKey)

        return Client(
            serverURL: URL(string: "https://api.openai.com/v1")!,
            transport: AsyncHTTPClientTransport(),
            middlewares: [
                authMiddleware,
            ]
        )}()

    @Test func makeSimpleRequest() async throws {

        let output = try await client
            .createChatCompletion(
                .init(
                    body:
                            .json(
                                .init(
                                    messages: [
                                        .ChatCompletionRequestSystemMessage(.init(content: .case1("Say hello"), role: .system)),
                                        .ChatCompletionRequestUserMessage(.init(content: .case1("Don't say hello"), role: .user))
                                    ],
                                    model: .init(value2: .gpt_hyphen_4o_hyphen_mini)
                                )
                            )
                )
            )
            .ok

        try output.body.json.choices.forEach { print($0.message) }
    }

    @Test func audioTranscriptionBuffered() async throws {

        let audioFileUrl = Bundle.module.url(forResource: "Resources/amazing-things", withExtension: "wav")!
        let audioData = try Data(contentsOf: audioFileUrl)

        //        For a buffered example, just provide an array of the part values, such as:
        let response = try await client.createTranscription(
            body: .multipartForm(
                [
                    .file(
                        .init(
                            payload: .init(
                                body: .init(
                                    audioData
                                )
                            ),
                            filename: audioFileUrl.lastPathComponent
                        )
                    ),
                    .model(.init(payload: .init(body: .init("whisper-1")))),
                    .response_format(
                        .init(
                            payload: .init(
                                body: .init(
                                    Components.Schemas.AudioResponseFormat.verbose_json.rawValue
                                )
                            )
                        )
                    )
                ]
            )
        )

        // ⚠️ Even though the server returns VerboseJson, we get Json here
        switch response {
        case .ok(let ok):
            switch try ok.body.json {
            case .CreateTranscriptionResponseVerboseJson(let verbose):
                dump(verbose)
            case .CreateTranscriptionResponseJson(let json):
                dump(json)
            }
        case .undocumented(let statusCode, let undocumentedPayload):
            let buffer = try await undocumentedPayload.body?.collect(upTo: 1024 * 1035 * 2, using: .init())
            let description = String(buffer: buffer!)
            print("❌", statusCode, description)

            struct myerror: Error {}
            throw ClientError.init(operationID: "", operationInput: "", causeDescription: "", underlyingError: myerror())
        }
    }
}
