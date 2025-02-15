import Foundation

func getEnvironmentVariable(_ name: String) -> String? {
    if let value = ProcessInfo.processInfo.environment[name] {
        return value
    }
    let currentFile = URL(fileURLWithPath: #filePath)
    let projectRoot =
        currentFile
        .deletingLastPathComponent()  // Remove 'main.swift'
        .deletingLastPathComponent()  // Remove 'Prepare'
        .deletingLastPathComponent()  // Remove 'Sources'
    let dotenv = projectRoot.appendingPathComponent(".env")
    let dotenvData = try! Data(contentsOf: dotenv)
    let dotenvString = String(data: dotenvData, encoding: .utf8)!
    let dotenvLines = dotenvString.split(separator: "\n")
    for line in dotenvLines {
        let parts = line.split(separator: "=")
        if parts[0] == name {
            return String(parts[1])
        }
    }
    return nil
}


