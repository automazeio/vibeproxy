import Foundation

struct ZAIAPIKeyLoadIssue: Equatable {
    let filePath: URL
    let message: String
}

struct ZAIAPIKeyLoadResult: Equatable {
    let apiKeys: [String]
    let issues: [ZAIAPIKeyLoadIssue]
}

enum ZAIAPIKeyStoreError: LocalizedError {
    case failedToCreateDirectory(String)
    case failedToSerializeKey(String)
    case failedToWriteKey(String)
    case failedToReadKey(String)
    case invalidKeyJSON(String)
    case malformedKey(String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let message),
             .failedToSerializeKey(let message),
             .failedToWriteKey(let message),
             .failedToReadKey(let message),
             .invalidKeyJSON(let message),
             .malformedKey(let message):
            return message
        }
    }
}

final class ZAIAPIKeyStore {
    static let authType = "zai"

    private let directoryURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String = "io.automaze.vibeproxy.zai-api-keys"
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    func save(
        apiKey: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> URL {
        try queue.sync {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                throw ZAIAPIKeyStoreError.failedToCreateDirectory(
                    "Failed to create auth directory at \(directoryURL.path): \(error.localizedDescription)"
                )
            }

            let filename = "zai-\(UUID().uuidString.prefix(8)).json"
            let filePath = directoryURL.appendingPathComponent(filename)
            let authData: [String: Any] = [
                "type": Self.authType,
                "email": maskAPIKey(apiKey),
                "api_key": apiKey,
                "created": createdAt
            ]

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            } catch {
                throw ZAIAPIKeyStoreError.failedToSerializeKey(
                    "Failed to serialize Z.AI API key: \(error.localizedDescription)"
                )
            }

            do {
                try jsonData.write(to: filePath, options: .atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            } catch {
                throw ZAIAPIKeyStoreError.failedToWriteKey(
                    "Failed to write Z.AI API key file at \(filePath.path): \(error.localizedDescription)"
                )
            }

            return filePath
        }
    }

    func loadActiveAPIKeys() -> ZAIAPIKeyLoadResult {
        queue.sync {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else {
                return ZAIAPIKeyLoadResult(apiKeys: [], issues: [])
            }

            var apiKeys: [String] = []
            var issues: [ZAIAPIKeyLoadIssue] = []

            for file in files where isManagedKeyFile(file) {
                do {
                    if let apiKey = try loadActiveAPIKey(at: file) {
                        apiKeys.append(apiKey)
                    }
                } catch let error as ZAIAPIKeyStoreError {
                    issues.append(
                        ZAIAPIKeyLoadIssue(
                            filePath: file,
                            message: error.localizedDescription
                        )
                    )
                } catch {
                    issues.append(
                        ZAIAPIKeyLoadIssue(
                            filePath: file,
                            message: "Unexpected error while loading \(file.path): \(error.localizedDescription)"
                        )
                    )
                }
            }

            return ZAIAPIKeyLoadResult(apiKeys: apiKeys, issues: issues)
        }
    }

    private func loadActiveAPIKey(at filePath: URL) throws -> String? {
        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw ZAIAPIKeyStoreError.failedToReadKey(
                "Failed to read Z.AI API key file at \(filePath.path): \(error.localizedDescription)"
            )
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ZAIAPIKeyStoreError.invalidKeyJSON(
                "Z.AI API key file at \(filePath.path) contains invalid JSON: \(error.localizedDescription)"
            )
        }

        guard let json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
            throw ZAIAPIKeyStoreError.malformedKey(
                "Z.AI API key file at \(filePath.path) must contain a JSON object."
            )
        }
        guard (json["type"] as? String) == Self.authType else {
            throw ZAIAPIKeyStoreError.malformedKey(
                "Z.AI API key file at \(filePath.path) has an unexpected type."
            )
        }
        guard let apiKey = json["api_key"] as? String, !apiKey.isEmpty else {
            throw ZAIAPIKeyStoreError.malformedKey(
                "Z.AI API key file at \(filePath.path) is missing an api_key."
            )
        }
        guard json["disabled"] as? Bool != true else {
            return nil
        }
        return apiKey
    }

    private func isManagedKeyFile(_ file: URL) -> Bool {
        file.lastPathComponent.hasPrefix("zai-") && file.pathExtension == "json"
    }

    private func maskAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 12 else {
            return apiKey
        }
        return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
    }
}
