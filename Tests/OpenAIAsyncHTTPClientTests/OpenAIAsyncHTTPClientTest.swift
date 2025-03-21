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
        let apiKey = getEnvironmentVariable("OPENAI_API_KEY")!

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
                                    Components.Schemas.AudioResponseFormat.srt.rawValue
                                )
                            )
                        )
                    )
                ]
            )
        )

        switch response {
        case .ok(let ok):

            switch ok.body {
            case .json(let jsonPayload):
                switch jsonPayload {
                case .CreateTranscriptionResponseVerboseJson(let verbose):
                    print("🥁")
                    dump(verbose)
                case .CreateTranscriptionResponseJson(let json):
                    print("🥁")
                    dump(json)
                }

            case .plainText(let httpBody):
                let buffer = try await httpBody.collect(upTo: 1024 * 1035 * 2, using: .init())
                let text = String(buffer: buffer)
                print("🥁", text)
            }

        case .undocumented(let statusCode, let undocumentedPayload):
            try await undocumentedPayloadPrinter(statusCode, undocumentedPayload)
        case .unauthorized(let unauthorized):
            switch unauthorized.body {
            case .json(let jsonPayload):
                dump(jsonPayload)
            }
        default:
            break
        }
    }

    @Test func decodingVerboseJsonString() async throws {
        let input = """
            {
              "task": "transcribe",
              "language": "english",
              "duration": 8.470000267028809,
              "text": "The beach was a popular spot on a hot summer day. People were swimming in the ocean, building sandcastles, and playing beach volleyball.",
              "segments": [
                {
                  "id": 0,
                  "seek": 0,
                  "start": 0.0,
                  "end": 3.319999933242798,
                  "text": " The beach was a popular spot on a hot summer day.",
                  "tokens": [
                    50364, 440, 7534, 390, 257, 3743, 4008, 322, 257, 2368, 4266, 786, 13, 50530
                  ],
                  "temperature": 0.0,
                  "avg_logprob": -0.2860786020755768,
                  "compression_ratio": 1.2363636493682861,
                  "no_speech_prob": 0.00985979475080967
                }
              ]
            }
            """

        let data = input.data(using: .utf8)!
        let decoder = JSONDecoder()
        let result = try! decoder.decode(Operations.createTranscription.Output.Ok.Body.jsonPayload.self, from: data)
        switch result {
        case .CreateTranscriptionResponseVerboseJson(let object):
            #expect(object.text.count >= 1)
        case .CreateTranscriptionResponseJson(_):
            assertionFailure()
        }
    }

    @Test func streamingChatCompletion() async throws {
        let response = try await client
            .createChatCompletion(
                .init(
                    body:
                            .json(
                                .init(
                                    messages: [
                                        .ChatCompletionRequestSystemMessage(.init(content: .case1("Say hello"), role: .system)),
                                        .ChatCompletionRequestUserMessage(.init(content: .case1("to Swift programming language"), role: .user))
                                    ],
                                    model: .init(value2: .gpt_hyphen_4o_hyphen_mini),
                                    stream: true
                                )
                            )
                )
            )

        switch response {
        case .ok(let ok):
            switch ok.body {
            case .text_event_hyphen_stream(let httpBody):
                let stream = httpBody.asDecodedServerSentEventsWithJSONData(of: Components.Schemas.CreateChatCompletionStreamResponse.self)
                do {
                    for try await event in stream {
                        // the last data is "[DONE]", that's why it will throw decoding error
                        guard let data = event.data else { continue }
                        data.choices.forEach {
                            print("|", $0.delta.content ?? "", terminator: " ")
                        }
                    }
                } catch {}
            case .json(_):
                struct notasked: Error {}
                throw notasked()
            }
        case .unauthorized(let unauthorized):
            switch unauthorized.body {
            case .json(let jsonPayload):
                dump(jsonPayload)
            }
        case .undocumented(let statusCode, let undocumentedPayload):
            try await undocumentedPayloadPrinter(statusCode, undocumentedPayload)
        default:
            break
        }

    }
    
    @Test func structuredOutput() async throws {
        let response = try await client.createChatCompletion(
            body: .json(
                .init(
                    messages: [
                        .ChatCompletionRequestSystemMessage(
                            .init(
                                content: .case1(
                                    "true if it is positive otherwie return false"
                                ),
                                role: .system
                            )
                        ),
                        .ChatCompletionRequestUserMessage(
                            .init(
                                content: .case1(
                                    "I like dictop. It's a great app."
                                ),
                                role: .user
                            )
                        )
                    ],
                    model: .init(value2: .gpt_hyphen_4o),
//                    store: <#T##Bool?#>,
//                    reasoning_effort: <#T##Components.Schemas.ReasoningEffort?#>,
//                    metadata: <#T##Components.Schemas.Metadata?#>,
//                    frequency_penalty: <#T##Double?#>,
//                    logit_bias: <#T##Components.Schemas.CreateChatCompletionRequest.logit_biasPayload?#>,
//                    logprobs: <#T##Bool?#>,
//                    top_logprobs: <#T##Int?#>,
//                    max_tokens: <#T##Int?#>,
//                    max_completion_tokens: <#T##Int?#>,
//                    n: <#T##Int?#>,
//                    modalities: <#T##Components.Schemas.ChatCompletionModalities?#>,
//                    prediction: <#T##Components.Schemas.CreateChatCompletionRequest.predictionPayload?#>,
//                    audio: <#T##Components.Schemas.CreateChatCompletionRequest.audioPayload?#>,
//                    presence_penalty: <#T##Double?#>,
                    response_format: .ResponseFormatJsonSchema(
                        .init(
                            _type: .json_schema,
                            json_schema: .init(
                                description: "boolean",
                                name: "sentiment",
                                schema: .init(
                                    additionalProperties: .init(
                                        unvalidatedValue: [
                                            "type": "object",
                                            "properties": [
                                                "sentiment": ["type": "boolean"]
                                            ],
                                            "additionalProperties": false,
                                            "required": ["sentiment"]
                                        ]
                                    )
                                ),
                                strict: true
                            )
                        )
                    )
//                    seed: <#T##Int64?#>,
//                    service_tier: <#T##Components.Schemas.CreateChatCompletionRequest.service_tierPayload?#>,
//                    stop: <#T##Components.Schemas.CreateChatCompletionRequest.stopPayload?#>,
//                    stream: <#T##Bool?#>,
//                    stream_options: <#T##Components.Schemas.ChatCompletionStreamOptions?#>,
//                    temperature: <#T##Double?#>,
//                    top_p: <#T##Double?#>,
//                    tools: <#T##[Components.Schemas.ChatCompletionTool]?#>,
//                    tool_choice: <#T##Components.Schemas.ChatCompletionToolChoiceOption?#>,
//                    parallel_tool_calls: <#T##Components.Schemas.ParallelToolCalls?#>,
//                    user: <#T##String?#>,
//                    function_call: <#T##Components.Schemas.CreateChatCompletionRequest.function_callPayload?#>,
//                    functions: <#T##[Components.Schemas.ChatCompletionFunctions]?#>
                )
            )
        )
        
        dump(response)
    }
}

func undocumentedPayloadPrinter(_ statusCode: Int, _ undocumentedPayload: UndocumentedPayload) async throws {
    let buffer = try await undocumentedPayload.body?.collect(upTo: 1024 * 1035 * 2, using: .init())
    let description = String(buffer: buffer!)
    print("❌", statusCode, description)

    struct myerror: Error {}
    throw myerror()
}
