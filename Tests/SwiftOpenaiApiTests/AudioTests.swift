import Foundation
import HTTPTypes
@_spi(Generated) import OpenAPIRuntime
import SwiftOpenaiApi
import SwiftOpenaiApiTypes
import Testing

struct AudioTests {
    @Test(arguments: [
        "transcription-json", "transcription-logprobs", "transcription-verbose", "transcription-diarized",
        "transcription-text", "transcription-srt", "transcription-vtt", "transcription-missing-file", "transcription-invalid-format",
    ])
    func generatedClientDecodesTranscription(name: String) async throws {
        let scenario = try scenario(name)
        let payload = try fixture(scenario.response)
        let response = try await transcription(name)
        if scenario.status == 400 {
            #expect(try response.badRequest.body.json == JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: payload))
        } else if scenario.contentType == "application/json" {
            let expected = try JSONDecoder().decode(Operations.createTranscription.Output.Ok.Body.jsonPayload.self, from: payload)
            #expect(try response.ok.body.json == expected)
            if name == "transcription-verbose" { #expect(expected.value3 != nil) }
            if name == "transcription-diarized" { #expect(expected.value2 != nil) }
        } else {
            let body = try response.ok.body.plainText
            #expect(try await Data(collecting: body, upTo: 1024 * 1024) == payload)
            let text = try #require(String(data: payload, encoding: .utf8))
            #expect(text.contains("decoding tests"))
            if name == "transcription-srt" { #expect(text.contains(" --> ")) }
            if name == "transcription-vtt" { #expect(text.hasPrefix("WEBVTT")) }
        }
    }

    @Test(arguments: ["speech-wav", "speech-mp3", "speech-pcm", "speech-aac", "speech-flac", "speech-opus", "speech-german", "speech-missing-input", "speech-unauthenticated"])
    func generatedClientDecodesSpeech(name: String) async throws {
        let scenario = try scenario(name)
        let payload = try fixture(scenario.response)
        let response = try await speech(name)
        if scenario.status != 200 {
            let expected = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: payload)
            if scenario.status == 400 { #expect(try response.badRequest.body.json == expected) }
            if scenario.status == 401 { #expect(try response.unauthorized.body.json == expected) }
            return
        }
        let body: HTTPBody
        switch try response.ok.body {
        case .audio_wav(let value):
            body = value
            #expect(payload.prefix(4) == Data("RIFF".utf8))
            #expect(payload.dropFirst(8).prefix(4) == Data("WAVE".utf8))
        case .audio_mpeg(let value): body = value
        case .audio_aac(let value): body = value
        case .audio_flac(let value):
            body = value
            #expect(payload.starts(with: Data("fLaC".utf8)))
        case .audio_opus(let value):
            body = value
            #expect(payload.starts(with: Data("OggS".utf8)))
        case .audio_pcm(let value):
            body = value
            #expect(payload.count.isMultiple(of: 2))
        default:
            Issue.record("Unexpected speech media type: \(scenario.contentType)")
            return
        }
        #expect(!payload.isEmpty)
        #expect(try await Data(collecting: body, upTo: 1024 * 1024) == payload)
    }

    @Test(arguments: ["translation-json", "translation-verbose", "translation-text", "translation-vtt", "translation-invalid-model"])
    func generatedClientDecodesTranslation(name: String) async throws {
        let scenario = try scenario(name)
        let payload = try fixture(scenario.response)
        let parts = try multipartParts(scenario.status == 200 ? name : "translation-json")
        let body: [Operations.createTranslation.Input.Body.multipartFormPayload] = try parts.map { part in
            let value = HTTPBody(part.body)
            switch part.name {
            case "file": return .file(.init(payload: .init(body: value), filename: part.filename))
            case "model": return .model(.init(payload: .init(body: value)))
            case "response_format": return .response_format(.init(payload: .init(body: value)))
            default: throw AudioFixtureError.unsupportedField(part.name)
            }
        }
        let response = try await client(scenario, expectedParts: parts).createTranslation(body: .multipartForm(.init(body)))
        if scenario.status == 404 {
            #expect(try response.notFound.body.json == JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: payload))
        } else if scenario.contentType == "application/json" {
            let expected = try JSONDecoder().decode(Operations.createTranslation.Output.Ok.Body.jsonPayload.self, from: payload)
            #expect(try response.ok.body.json == expected)
            #expect(try #require(expected.value1).text.contains("Hello"))
            if name == "translation-verbose" {
                #expect(try #require(expected.value2).language == "english")
                #expect(try #require(expected.value2?.segments).isEmpty == false)
            }
        } else {
            #expect(try await Data(collecting: response.ok.body.plainText, upTo: 1024 * 1024) == payload)
            #expect(try #require(String(data: payload, encoding: .utf8)).contains("Hello"))
            if name == "translation-vtt" { #expect(payload.starts(with: Data("WEBVTT".utf8))) }
        }
    }

    @Test(arguments: ["transcription-json", "transcription-logprobs", "transcription-verbose", "transcription-diarized"])
    func decodesTranscription(name: String) throws {
        let payload = try fixture(name + ".json")
        let response = try JSONDecoder().decode(Operations.createTranscription.Output.Ok.Body.jsonPayload.self, from: payload)
        let simple = try #require(response.value1)
        #expect(simple.text.contains("decoding tests"))
        if name == "transcription-json" {
            #expect(try #require(simple.languages).map(\.code) == ["en"])
            guard case .TranscriptTextUsageDuration(let usage) = try #require(simple.usage) else {
                Issue.record("Expected duration usage from gpt-transcribe")
                return
            }
            #expect(usage.seconds > 0)
        }
        if name == "transcription-logprobs" {
            let logprobs = try #require(simple.logprobs)
            #expect(!logprobs.isEmpty)
            #expect(logprobs.compactMap(\.token).joined() == simple.text)
            #expect(logprobs.allSatisfy { $0.logprob != nil && $0.bytes?.isEmpty == false })
            guard case .TranscriptTextUsageTokens(let usage) = try #require(simple.usage) else {
                Issue.record("Expected token usage from gpt-4o-mini-transcribe")
                return
            }
            #expect(usage.total_tokens == usage.input_tokens + usage.output_tokens)
            #expect(try #require(usage.input_token_details?.audio_tokens) > 0)
        }
        if name == "transcription-verbose" {
            let expected = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseVerboseJson.self, from: payload)
            #expect(try #require(response.value3) == expected)
            #expect(try #require(expected.words).isEmpty == false)
            #expect(try #require(expected.segments).isEmpty == false)
            #expect(expected.words?.allSatisfy { $0.start >= 0 && $0.end >= $0.start } == true)
            #expect(expected.segments?.allSatisfy { !$0.tokens.isEmpty && $0.end >= $0.start } == true)
        }
        if name == "transcription-diarized" {
            let expected = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseDiarizedJson.self, from: payload)
            #expect(try #require(response.value2) == expected)
            #expect(!expected.segments.isEmpty)
            #expect(expected.segments.allSatisfy { !$0.id.isEmpty && !$0.speaker.isEmpty && $0.end >= $0.start })
            guard case .tokens(let usage) = try #require(expected.usage) else {
                Issue.record("Expected diarized token usage")
                return
            }
            #expect(usage.total_tokens == usage.input_tokens + usage.output_tokens)
        }
    }

    @Test func retainsVerboseTranslation() throws {
        let payload = try fixture("translation-verbose.json")
        let response = try JSONDecoder().decode(Operations.createTranslation.Output.Ok.Body.jsonPayload.self, from: payload)
        let verbose = try #require(response.value2)
        #expect(verbose.duration > 0)
        #expect(try #require(verbose.segments).isEmpty == false)
    }

    @Test func decodesSpeechStreamThroughGeneratedClient() async throws {
        let response = try await speech("speech-stream")
        let body = try response.ok.body.text_event_hyphen_stream
        var audio = Data()
        var terminal: Components.Schemas.SpeechAudioDoneEvent?
        var receivedDone = false
        for try await event in body.asDecodedServerSentEvents() {
            let data = try #require(event.data)
            #expect(!receivedDone)
            if data == "[DONE]" {
                #expect(terminal != nil)
                receivedDone = true
                continue
            }
            #expect(terminal == nil)
            let decoded = try JSONDecoder().decode(Components.Schemas.CreateSpeechResponseStreamEvent.self, from: Data(data.utf8))
            switch decoded {
            case .speech_period_audio_period_delta(let value):
                let chunk = try #require(Data(base64Encoded: value.audio))
                #expect(!chunk.isEmpty && chunk.count.isMultiple(of: 2))
                audio.append(chunk)
            case .speech_period_audio_period_done(let value): terminal = value
            }
        }
        #expect(receivedDone)
        #expect(!audio.isEmpty)
        let usage = try #require(terminal).usage
        #expect(usage.total_tokens == usage.input_tokens + usage.output_tokens)
        #expect(usage.output_tokens > 0)
    }

    @Test(arguments: ["transcription-stream", "transcription-diarized-stream", "transcription-language-stream"])
    func decodesTranscriptionStreamThroughGeneratedClient(name: String) async throws {
        let response = try await transcription(name)
        let body = try response.ok.body.text_event_hyphen_stream
        var text = ""
        var terminal: Components.Schemas.TranscriptTextDoneEvent?
        var receivedDone = false
        var segmentIDs: Set<String> = []
        var streamedLogprobs = ""
        for try await event in body.asDecodedServerSentEvents() {
            let data = try #require(event.data)
            #expect(!receivedDone)
            if data == "[DONE]" {
                #expect(terminal != nil)
                receivedDone = true
                continue
            }
            #expect(terminal == nil)
            let decoded = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseStreamEvent.self, from: Data(data.utf8))
            switch decoded {
            case .transcript_period_text_period_delta(let value):
                text += value.delta
                if name == "transcription-stream" {
                    let logprobs = try #require(value.logprobs)
                    #expect(logprobs.compactMap(\.token).joined() == value.delta)
                    streamedLogprobs += logprobs.compactMap(\.token).joined()
                }
            case .transcript_period_text_period_segment(let value):
                #expect(name == "transcription-diarized-stream")
                #expect(segmentIDs.insert(value.id).inserted)
                #expect(!value.speaker.isEmpty && value.end >= value.start)
                text += value.text
            case .transcript_period_text_period_done(let value): terminal = value
            }
        }
        #expect(receivedDone)
        let final = try #require(terminal)
        #expect(!final.text.isEmpty)
        #expect(final.text == text.trimmingCharacters(in: .whitespacesAndNewlines))
        let usage = try #require(final.usage)
        if name == "transcription-language-stream" {
            #expect(try #require(final.languages).map(\.code) == ["en"])
            guard case .duration(let duration) = usage else {
                Issue.record("Expected duration usage in gpt-transcribe's terminal event")
                return
            }
            #expect(duration.seconds > 0)
        } else {
            guard case .tokens(let tokens) = usage else {
                Issue.record("Expected token usage in the terminal event")
                return
            }
            #expect(tokens.total_tokens == tokens.input_tokens + tokens.output_tokens)
            #expect(try #require(tokens.input_token_details?.audio_tokens) > 0)
        }
        if name == "transcription-stream" {
            #expect(streamedLogprobs == final.text)
            #expect(try #require(final.logprobs).compactMap(\.token).joined() == final.text)
        }
        if name == "transcription-diarized-stream" { #expect(!segmentIDs.isEmpty) }
    }

    @Test(arguments: ["speech-missing-input", "speech-unauthenticated", "transcription-missing-file", "transcription-invalid-format", "translation-invalid-model"])
    func decodesError(name: String) throws {
        let error = try JSONDecoder().decode(Components.Schemas.ErrorResponse.self, from: fixture(name + ".json")).error
        #expect(!error.message.isEmpty)
        #expect(error._type == "invalid_request_error")
        if name == "speech-missing-input" {
            #expect(error.param == "input")
            #expect(error.code == "missing_required_parameter")
        } else {
            #expect(error.param == nil)
            #expect(error.code == nil)
        }
    }

    @Test(arguments: ["text", "duration", "segments", "task"])
    func stillRejectsMissingRequiredDiarizedFields(field: String) throws {
        var object = try #require(JSONSerialization.jsonObject(with: fixture("transcription-diarized.json")) as? [String: Any])
        object.removeValue(forKey: field)
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseDiarizedJson.self, from: modified)
        }
    }

    @Test func acceptsAdditionalFields() throws {
        let payload = try fixture("transcription-diarized.json")
        let expected = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseDiarizedJson.self, from: payload)
        var object = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        object["future_audio_field"] = ["enabled": true]
        var segments = try #require(object["segments"] as? [[String: Any]])
        segments[0]["future_segment_field"] = 42
        object["segments"] = segments
        let modified = try JSONSerialization.data(withJSONObject: object)
        #expect(try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseDiarizedJson.self, from: modified) == expected)
    }

    @Test(arguments: ["speech.audio.future", "transcript.text.future"])
    func rejectsUnknownStreamEventTypes(type: String) throws {
        let payload = try JSONSerialization.data(withJSONObject: ["type": type, "delta": "text", "audio": "AA=="])
        #expect(throws: DecodingError.self) {
            if type.hasPrefix("speech.") {
                _ = try JSONDecoder().decode(Components.Schemas.CreateSpeechResponseStreamEvent.self, from: payload)
            } else {
                _ = try JSONDecoder().decode(Components.Schemas.CreateTranscriptionResponseStreamEvent.self, from: payload)
            }
        }
    }

    private func speech(_ name: String) async throws -> Operations.createSpeech.Output {
        let scenario = try scenario(name)
        let requestPayload = try fixture("Requests/\(scenario.status == 200 ? name : "speech-wav").json")
        let transport = AudioFixtureTransport(scenario: scenario, payload: try fixture(scenario.response), expectedJSON: requestPayload)
        let client = Client(serverURL: try Servers.Server1.url(), transport: transport)
        let request = try JSONDecoder().decode(Components.Schemas.CreateSpeechRequest.self, from: requestPayload)
        return try await client.createSpeech(body: .json(request))
    }

    private func transcription(_ name: String) async throws -> Operations.createTranscription.Output {
        let scenario = try scenario(name)
        let requestName = scenario.status == 200 ? name : "transcription-json"
        let parts = try multipartParts(requestName)
        let body: [Operations.createTranscription.Input.Body.multipartFormPayload] = try parts.map { part in
            let value = HTTPBody(part.body)
            switch part.name {
            case "file": return .file(.init(payload: .init(body: value), filename: part.filename))
            case "model": return .model(.init(payload: .init(body: value)))
            case "response_format": return .response_format(.init(payload: .init(body: value)))
            case "languages[]": return .languages(.init(payload: .init(body: value)))
            case "keywords[]": return .keywords(.init(payload: .init(body: value)))
            case "include[]": return .include(.init(payload: .init(body: value)))
            case "timestamp_granularities[]": return .timestamp_granularities(.init(payload: .init(body: value)))
            case "stream": return .stream(.init(payload: .init(body: value)))
            default: throw AudioFixtureError.unsupportedField(part.name)
            }
        }
        return try await client(scenario, expectedParts: parts).createTranscription(body: .multipartForm(.init(body)))
    }

    private func client(_ scenario: AudioScenario, expectedParts: [AudioPart]) throws -> Client {
        Client(
            serverURL: try Servers.Server1.url(),
            configuration: .init(multipartBoundaryGenerator: .constant),
            transport: AudioFixtureTransport(scenario: scenario, payload: try fixture(scenario.response), expectedParts: expectedParts)
        )
    }
}

private func fixture(_ filename: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: filename, withExtension: nil, subdirectory: "Resources/Audio"))
    return try Data(contentsOf: url)
}

private struct AudioScenario: Decodable, Sendable {
    let name: String
    let endpoint: String
    let response: String
    let status: Int
    let contentType: String
    enum CodingKeys: String, CodingKey {
        case name, endpoint, response, status
        case contentType = "content_type"
    }
}

private func scenario(_ name: String) throws -> AudioScenario {
    let scenarios = try JSONDecoder().decode([AudioScenario].self, from: fixture("cases.json"))
    return try #require(scenarios.first { $0.name == name })
}

private struct AudioPart: Equatable, Sendable {
    let name: String
    let filename: String?
    let body: Data
}

private enum AudioFixtureError: Error {
    case unsupportedField(String)
}

private func multipartParts(_ name: String) throws -> [AudioPart] {
    let object = try #require(JSONSerialization.jsonObject(with: fixture("Requests/\(name).json")) as? [String: Any])
    return try object.keys.sorted()
        .flatMap { key -> [AudioPart] in
            if key == "file" {
                let filename = try #require(object[key] as? String)
                return [AudioPart(name: key, filename: filename, body: try fixture(filename))]
            }
            let value = try #require(object[key])
            let values = (value as? [Any]) ?? [value]
            return try values.map { item in
                let body: Data
                if let string = item as? String {
                    body = Data(string.utf8)
                } else {
                    body = try JSONSerialization.data(withJSONObject: item, options: [.fragmentsAllowed, .sortedKeys])
                }
                return AudioPart(name: key + (value is [Any] ? "[]" : ""), filename: nil, body: body)
            }
        }
}

private struct AudioFixtureTransport: ClientTransport {
    let scenario: AudioScenario
    let payload: Data
    var expectedParts: [AudioPart] = []
    var expectedJSON: Data? = nil

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(request.method == .post)
        #expect(request.path == "/" + scenario.endpoint)
        #expect(baseURL.absoluteString == "https://api.openai.com/v1")
        switch scenario.endpoint {
        case "audio/speech": #expect(operationID == Operations.createSpeech.id)
        case "audio/transcriptions": #expect(operationID == Operations.createTranscription.id)
        case "audio/translations": #expect(operationID == Operations.createTranslation.id)
        default: Issue.record("Unexpected Audio endpoint: \(scenario.endpoint)")
        }
        if let expectedJSON {
            #expect(request.headerFields[.contentType]?.split(separator: ";").first == "application/json")
            let data = try await Data(collecting: #require(body), upTo: 64 * 1024)
            let actual = try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
            let expected = try #require(JSONSerialization.jsonObject(with: expectedJSON) as? NSDictionary)
            #expect(actual == expected)
        } else {
            try await verifyMultipart(request, body: body)
        }
        let captures = try JSONDecoder().decode([AudioCapture].self, from: fixture("captures.json"))
        let capture = try #require(captures.first { $0.name == scenario.name })
        #expect(capture.status == scenario.status)
        #expect(capture.contentType.split(separator: ";").first.map(String.init) == scenario.contentType)
        return (HTTPResponse(status: .init(code: capture.status), headerFields: [.contentType: capture.contentType]), HTTPBody(payload))
    }

    private func verifyMultipart(_ request: HTTPRequest, body: HTTPBody?) async throws {
        let converter = Converter(configuration: .init())
        let boundary = ConstantMultipartBoundaryGenerator().boundary
        #expect(request.headerFields[.contentType] == "multipart/form-data; boundary=\(boundary)")
        let parts = try converter.getRequiredRequestBodyAsMultipart(
            MultipartBody<MultipartRawPart>.self,
            from: body,
            transforming: { $0 },
            boundary: boundary,
            allowsUnknownParts: true,
            requiredExactlyOncePartNames: [],
            requiredAtLeastOncePartNames: [],
            atMostOncePartNames: [],
            zeroOrMoreTimesPartNames: [],
            decoding: { $0 }
        )
        var actual: [AudioPart] = []
        for try await part in parts {
            let (name, filename) = try converter.extractContentDispositionNameAndFilename(in: part.headerFields)
            if name == "file" { #expect(part.headerFields[.contentType] == "application/octet-stream") }
            let data = try await Data(collecting: part.body, upTo: 1024 * 1024)
            actual.append(AudioPart(name: try #require(name), filename: filename, body: data))
        }
        #expect(actual == expectedParts)
    }
}

private struct AudioCapture: Decodable {
    let name: String
    let status: Int
    let contentType: String
    enum CodingKeys: String, CodingKey {
        case name, status
        case contentType = "content_type"
    }
}
