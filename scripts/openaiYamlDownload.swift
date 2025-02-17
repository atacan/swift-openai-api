import Foundation

let fileURL = URL(
    string: "https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml"
)!
let destinationPaths = [
    "./Sources/OpenAIUrlSessionClient/openapi.yaml",
    "./Sources/OpenAIAsyncHTTPClient/openapi.yaml",
]

func downloadFile(from fileURL: URL, to destinationPaths: [String]) async throws {
    let (tempLocalUrl, _) = try await URLSession.shared.download(from: fileURL)

    let fileData = try Data(contentsOf: tempLocalUrl)
    var fileContent = try String(data: fileData, encoding: .utf8)!

    let errorResponses = """
        "400":
          description: The request was malformed, missing required fields, or invalid parameters
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "401":
          description: Invalid Authentication, Incorrect API key provided, You must be a member of an organization to use the API
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "403":
          description: Country, region, or territory not supported
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "429":
          description: Rate limit reached for requests, You exceeded your current quota, please check your plan and billing details
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "500":
          description: The server had an error while processing your request
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
        "503":
          description: The engine is currently overloaded, please try again later
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/ErrorResponse"
"""

    // Apply content modifications
    fileContent = fileContent
                    // Fix overflowing integer
                    .replacingOccurrences(of: "9223372036854776000", with: "922337203685477600")
                    // Fix duplicate models
                    .replacingOccurrences(
                        of: """
                                            - gpt-4o-2024-08-06
                                            - gpt-4o-2024-05-13
                                            - gpt-4o-2024-08-06
                            """,
                        with: """
                                            - gpt-4o-2024-08-06
                                            - gpt-4o-2024-05-13
                            """
                    )
                    // Fix wrong type
                    .replacingOccurrences(
                        of: """
        duration:
          type: string
          description: The duration of the input audio.
""",
                        with: """
        duration:
          type: number
          description: The duration of the input audio.
"""
                    )
                    // Try to decode verbose json first and add text/plain content type
                    // Add error responses
                    .replacingOccurrences(
                        of: """
            application/json:
              schema:
                oneOf:
                  - $ref: "#/components/schemas/CreateTranscriptionResponseJson"
                  - $ref: "#/components/schemas/CreateTranscriptionResponseVerboseJson"
""",
                        with: """
            application/json:
              schema:
                oneOf:
                  - $ref: "#/components/schemas/CreateTranscriptionResponseVerboseJson"
                  - $ref: "#/components/schemas/CreateTranscriptionResponseJson"
            text/plain:
              schema:
                type: string
""" + "\n" + errorResponses
                    )
                    // Try to decode verbose json first and add text/plain content type
                    // Add error responses
                    .replacingOccurrences(
                        of: """
            application/json:
              schema:
                oneOf:
                  - $ref: "#/components/schemas/CreateTranslationResponseJson"
                  - $ref: "#/components/schemas/CreateTranslationResponseVerboseJson"
""",
                        with: """
            application/json:
              schema:
                oneOf:
                  - $ref: "#/components/schemas/CreateTranslationResponseVerboseJson"
                  - $ref: "#/components/schemas/CreateTranslationResponseJson"
            text/plain:
              schema:
                type: string
""" + "\n" + errorResponses
                    )
                    // Add streaming response
                    // Add error responses
                    .replacingOccurrences(
                        of: """
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/CreateChatCompletionResponse"
""",
                        with: """
          content:
            application/json:
              schema:
                $ref: "#/components/schemas/CreateChatCompletionResponse"
            text/event-stream:
              schema:
                $ref: "#/components/schemas/CreateChatCompletionStreamResponse"
""" + "\n" + errorResponses
                    )

    // Save to each destination path
    try await withThrowingTaskGroup(of: Void.self) { group in
        for destinationPath in destinationPaths {
            group.addTask {
                try fileContent.write(
                    toFile: destinationPath,
                    atomically: true,
                    encoding: .utf8
                )
                print("Successfully downloaded and saved file to: \(destinationPath)")
            }
        }
        try await group.waitForAll()
    }
}

// Execute the download
try await downloadFile(from: fileURL, to: destinationPaths)
