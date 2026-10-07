import Foundation
import SwiftOpenaiApiRealtimeTypes
import Testing

struct RealtimeTypesTests {
    @Test(arguments: [false, true])
    func roundTripsInputAudioBufferAppend(includingEventID: Bool) throws {
        let audio = Data([0, 1, 2, 127, 128, 255])
        let event = Components.Schemas.RealtimeClientEventInputAudioBufferAppend(
            event_id: includingEventID ? "client_audio_1" : nil,
            _type: .input_audio_buffer_period_append,
            audio: audio.base64EncodedString()
        )
        let data = try JSONEncoder().encode(event)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["type"] as? String == "input_audio_buffer.append")
        #expect(object["audio"] as? String == audio.base64EncodedString())
        #expect(object["event_id"] as? String == event.event_id)
        #expect(Set(object.keys) == (includingEventID ? ["type", "audio", "event_id"] : ["type", "audio"]))
        let decoded = try JSONDecoder().decode(Components.Schemas.RealtimeClientEventInputAudioBufferAppend.self, from: data)
        #expect(decoded == event)
        #expect(Data(base64Encoded: decoded.audio) == audio)
    }

    @Test(arguments: ["near_field", "far_field"])
    func roundTripsTranscriptionSessionUpdate(noiseReduction: String) throws {
        let object: [String: Any] = [
            "type": "transcription_session.update",
            "event_id": "client_session_1",
            "session": [
                "input_audio_format": "pcm16",
                "input_audio_transcription": ["model": "gpt-4o-transcribe", "language": "en", "prompt": "Names"],
                "input_audio_noise_reduction": ["type": noiseReduction],
                "turn_detection": ["type": "server_vad", "threshold": 0.5, "prefix_padding_ms": 300, "silence_duration_ms": 500],
                "include": ["item.input_audio_transcription.logprobs"],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: object)
        let event = try JSONDecoder().decode(Components.Schemas.RealtimeClientEventTranscriptionSessionUpdate.self, from: data)
        #expect(event.event_id == "client_session_1")
        #expect(event._type == .transcription_session_period_update)
        #expect(event.session.input_audio_format == .pcm16)
        #expect(event.session.input_audio_noise_reduction?._type?.rawValue == noiseReduction)
        #expect(event.session.turn_detection?.threshold == 0.5)
        #expect(event.session.input_audio_transcription?.language == "en")
        #expect(try jsonObject(JSONEncoder().encode(event)) == NSDictionary(dictionary: object))
    }

    @Test(arguments: [false, true])
    func acceptsOmittedAndNullNoiseReduction(includingNull: Bool) throws {
        let session: [String: Any] = includingNull ? ["input_audio_noise_reduction": NSNull()] : [:]
        let data = try JSONSerialization.data(withJSONObject: ["type": "transcription_session.update", "session": session])
        let event = try JSONDecoder().decode(Components.Schemas.RealtimeClientEventTranscriptionSessionUpdate.self, from: data)
        #expect(event.event_id == nil)
        #expect(event.session.input_audio_noise_reduction == nil)
    }

    @Test(arguments: ["tokens", "duration"])
    func decodesCompletedTranscriptionDirectlyAndThroughServerEvent(usageType: String) throws {
        let object = completedTranscription(usageType: usageType)
        let data = try JSONSerialization.data(withJSONObject: object)
        let concrete = try JSONDecoder().decode(Components.Schemas.RealtimeServerEventConversationItemInputAudioTranscriptionCompleted.self, from: data)
        #expect(concrete.event_id == "event_1")
        #expect(concrete.item_id == "item_1")
        #expect(concrete.content_index == 0)
        #expect(concrete.transcript == "Hello")
        switch concrete.usage {
        case .TranscriptTextUsageTokens(let tokens):
            #expect(usageType == "tokens")
            #expect(tokens.input_tokens == 12)
            #expect(tokens.output_tokens == 3)
            #expect(tokens.total_tokens == 15)
            #expect(tokens.input_token_details?.audio_tokens == 12)
        case .TranscriptTextUsageDuration(let duration):
            #expect(usageType == "duration")
            #expect(duration.seconds == 1.25)
        }
        let event = try JSONDecoder().decode(Components.Schemas.RealtimeServerEvent.self, from: data)
        guard case .conversation_period_item_period_input_audio_transcription_period_completed(let payload) = event else {
            Issue.record("Expected a completed transcription event")
            return
        }
        #expect(payload == concrete)
        #expect(try jsonObject(JSONEncoder().encode(event)) == NSDictionary(dictionary: object))
    }

    @Test(arguments: ["realtime.future_event", "RealtimeServerEventConversationItemInputAudioTranscriptionCompleted"])
    func rejectsUnknownServerEventTypes(type: String) throws {
        var object = completedTranscription(usageType: "duration")
        object["type"] = type
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeServerEvent.self, from: data)
        }
    }

    @Test(arguments: ["event_id", "type", "item_id", "content_index", "transcript", "usage"])
    func rejectsMissingRequiredTranscriptionFields(field: String) throws {
        var object = completedTranscription(usageType: "duration")
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeServerEventConversationItemInputAudioTranscriptionCompleted.self, from: data)
        }
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeServerEvent.self, from: data)
        }
    }

    @Test(arguments: ["type", "audio"])
    func rejectsMissingRequiredAudioAppendFields(field: String) throws {
        var object = ["type": "input_audio_buffer.append", "audio": "AQID"]
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeClientEventInputAudioBufferAppend.self, from: data)
        }
    }

    @Test(arguments: ["type", "session"])
    func rejectsMissingRequiredSessionUpdateFields(field: String) throws {
        var object: [String: Any] = ["type": "transcription_session.update", "session": [:] as [String: Any]]
        object.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeClientEventTranscriptionSessionUpdate.self, from: data)
        }
    }

    @Test(arguments: ["server_vad", "semantic_vad"])
    func roundTripsTurnDetection(type: String) throws {
        let object: [String: Any] = type == "server_vad" ? ["type": type, "threshold": 0.5] : ["type": type, "eagerness": "auto"]
        let data = try JSONSerialization.data(withJSONObject: object)
        let turnDetection = try JSONDecoder().decode(Components.Schemas.RealtimeTurnDetection.self, from: data)
        switch turnDetection {
        case .case1(let serverVAD):
            #expect(type == "server_vad")
            #expect(serverVAD._type == .server_vad)
            #expect(serverVAD.threshold == 0.5)
        case .case2(let semanticVAD):
            #expect(type == "semantic_vad")
            #expect(semanticVAD._type == .semantic_vad)
            #expect(semanticVAD.eagerness == .auto)
        }
        #expect(try jsonObject(JSONEncoder().encode(turnDetection)) == NSDictionary(dictionary: object))
    }

    @Test func rejectsUnknownTurnDetectionType() throws {
        let data = Data(#"{"type":"future_vad"}"#.utf8)
        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(Components.Schemas.RealtimeTurnDetection.self, from: data)
        }
    }

    private func completedTranscription(usageType: String) -> [String: Any] {
        let usage: [String: Any] =
            usageType == "tokens"
            ? ["type": "tokens", "input_tokens": 12, "output_tokens": 3, "total_tokens": 15, "input_token_details": ["text_tokens": 0, "audio_tokens": 12]]
            : ["type": "duration", "seconds": 1.25]
        return [
            "type": "conversation.item.input_audio_transcription.completed",
            "event_id": "event_1",
            "item_id": "item_1",
            "content_index": 0,
            "transcript": "Hello",
            "usage": usage,
        ]
    }

    private func jsonObject(_ data: Data) throws -> NSDictionary {
        try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
    }
}
