import Foundation

let fileURL = URL(string: "https://raw.githubusercontent.com/openai/openai-openapi/master/openapi.yaml")!
let destinationPaths = ["./Sources/OpenAIUrlSessionClient/openapi.yaml", "./Sources/OpenAIAsyncHTTPClient/openapi.yaml"]

func downloadFile(from fileURL: URL, to destinationPaths: [String]) {
    let semaphore = DispatchSemaphore(value: 0)
    let task = URLSession.shared.downloadTask(with: fileURL) { (tempLocalUrl, response, error) in
        if let tempLocalUrl = tempLocalUrl, error == nil {
            do {
                let fileData = try Data(contentsOf: tempLocalUrl)
                try destinationPaths.forEach { destinationPath in
                    try fileData.write(to: URL(fileURLWithPath: destinationPath), options: .atomic)
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
