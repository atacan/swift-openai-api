import Foundation

let fileURL = URL(
    string: "https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml"
)!
let destinationPaths = [
    "./Sources/OpenAIUrlSessionClient/openapi.yaml", "./Sources/OpenAIAsyncHTTPClient/openapi.yaml",
]

func downloadFile(from fileURL: URL, to destinationPaths: [String]) {
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.downloadTask(with: fileURL) { (tempLocalUrl, response, error) in
        if let tempLocalUrl = tempLocalUrl, error == nil {
            do {
                let fileData = try Data(contentsOf: tempLocalUrl)
                var fileContent: String = String(data: fileData, encoding: .utf8)!
                fileContent =
                    fileContent
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
                    // Try to decode verbose json first
                    .replacingOccurrences(
                        of: """
                  - $ref: "#/components/schemas/CreateTranscriptionResponseJson"
                  - $ref: "#/components/schemas/CreateTranscriptionResponseVerboseJson"
""",
                        with: """
                  - $ref: "#/components/schemas/CreateTranscriptionResponseVerboseJson"
                  - $ref: "#/components/schemas/CreateTranscriptionResponseJson"
"""
                    )
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
                
                // Save to each destination path
                try destinationPaths.forEach { destinationPath in
                    try fileContent.write(
                        toFile: destinationPath,
                        atomically: true,
                        encoding: .utf8
                    )
                    print("Successfully downloaded and saved file to: \(destinationPath)")
                }
            }
            catch {
                print("Error saving file \(error)")
            }
        }
        else {
            print("Error downloading file: \(error!.localizedDescription)")
        }
        semaphore.signal()
    }
    task.resume()
    semaphore.wait()
}

downloadFile(from: fileURL, to: destinationPaths)
