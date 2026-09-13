import Foundation

struct ManagedProviderAPIKeyLoadIssue: Equatable {
    let filePath: URL
    let message: String
}

struct ManagedProviderAPIKeyLoadResult: Equatable {
    let apiKeys: [String]
    let issues: [ManagedProviderAPIKeyLoadIssue]
}

enum ManagedProviderAPIKeyStoreError: LocalizedError {
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

private struct ManagedProviderAPIKeyDescriptor {
    let authType: String
    let filePrefix: String
    let displayName: String
}

private final class ManagedProviderAPIKeyStore {
    private let descriptor: ManagedProviderAPIKeyDescriptor
    private let directoryURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue

    init(
        descriptor: ManagedProviderAPIKeyDescriptor,
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String
    ) {
        self.descriptor = descriptor
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
                throw ManagedProviderAPIKeyStoreError.failedToCreateDirectory(
                    "Failed to create auth directory at \(directoryURL.path): \(error.localizedDescription)"
                )
            }

            let filename = "\(descriptor.filePrefix)-\(UUID().uuidString.prefix(8)).json"
            let filePath = directoryURL.appendingPathComponent(filename)
            let authData: [String: Any] = [
                "type": descriptor.authType,
                "email": maskAPIKey(apiKey),
                "api_key": apiKey,
                "created": createdAt
            ]

            let jsonData: Data
            do {
                jsonData = try JSONSerialization.data(withJSONObject: authData, options: .prettyPrinted)
            } catch {
                throw ManagedProviderAPIKeyStoreError.failedToSerializeKey(
                    "Failed to serialize \(descriptor.displayName) API key: \(error.localizedDescription)"
                )
            }

            do {
                try jsonData.write(to: filePath, options: .atomic)
                try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
            } catch {
                throw ManagedProviderAPIKeyStoreError.failedToWriteKey(
                    "Failed to write \(descriptor.displayName) API key file at \(filePath.path): \(error.localizedDescription)"
                )
            }

            return filePath
        }
    }

    func loadActiveAPIKeys() -> ManagedProviderAPIKeyLoadResult {
        queue.sync {
            guard let files = try? fileManager.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: nil
            ) else {
                return ManagedProviderAPIKeyLoadResult(apiKeys: [], issues: [])
            }

            var apiKeys: [String] = []
            var issues: [ManagedProviderAPIKeyLoadIssue] = []

            for file in files where isManagedKeyFile(file) {
                do {
                    if let apiKey = try loadActiveAPIKey(at: file) {
                        apiKeys.append(apiKey)
                    }
                } catch let error as ManagedProviderAPIKeyStoreError {
                    issues.append(
                        ManagedProviderAPIKeyLoadIssue(
                            filePath: file,
                            message: error.localizedDescription
                        )
                    )
                } catch {
                    issues.append(
                        ManagedProviderAPIKeyLoadIssue(
                            filePath: file,
                            message: "Unexpected error while loading \(file.path): \(error.localizedDescription)"
                        )
                    )
                }
            }

            return ManagedProviderAPIKeyLoadResult(apiKeys: apiKeys, issues: issues)
        }
    }

    private func loadActiveAPIKey(at filePath: URL) throws -> String? {
        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw ManagedProviderAPIKeyStoreError.failedToReadKey(
                "Failed to read \(descriptor.displayName) API key file at \(filePath.path): \(error.localizedDescription)"
            )
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw ManagedProviderAPIKeyStoreError.invalidKeyJSON(
                "\(descriptor.displayName) API key file at \(filePath.path) contains invalid JSON: \(error.localizedDescription)"
            )
        }

        guard let json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
            throw ManagedProviderAPIKeyStoreError.malformedKey(
                "\(descriptor.displayName) API key file at \(filePath.path) must contain a JSON object."
            )
        }
        guard (json["type"] as? String) == descriptor.authType else {
            throw ManagedProviderAPIKeyStoreError.malformedKey(
                "\(descriptor.displayName) API key file at \(filePath.path) has an unexpected type."
            )
        }
        guard let apiKey = json["api_key"] as? String, !apiKey.isEmpty else {
            throw ManagedProviderAPIKeyStoreError.malformedKey(
                "\(descriptor.displayName) API key file at \(filePath.path) is missing an api_key."
            )
        }
        guard json["disabled"] as? Bool != true else {
            return nil
        }
        return apiKey
    }

    private func isManagedKeyFile(_ file: URL) -> Bool {
        file.lastPathComponent.hasPrefix("\(descriptor.filePrefix)-") && file.pathExtension == "json"
    }

    private func maskAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 12 else {
            return apiKey
        }
        return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
    }
}

final class ZAIAPIKeyStore {
    private let backingStore: ManagedProviderAPIKeyStore

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String = "io.automaze.vibeproxy.zai-api-keys"
    ) {
        self.backingStore = ManagedProviderAPIKeyStore(
            descriptor: ManagedProviderAPIKeyDescriptor(
                authType: ProviderCatalog.managedZAIProviderName,
                filePrefix: ProviderCatalog.managedZAIProviderName,
                displayName: "Z.AI"
            ),
            directoryURL: directoryURL,
            fileManager: fileManager,
            queueLabel: queueLabel
        )
    }

    func save(
        apiKey: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> URL {
        try backingStore.save(apiKey: apiKey, createdAt: createdAt)
    }

    func loadActiveAPIKeys() -> ManagedProviderAPIKeyLoadResult {
        backingStore.loadActiveAPIKeys()
    }
}

final class MiniMaxAPIKeyStore {
    private let backingStore: ManagedProviderAPIKeyStore

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String = "io.automaze.vibeproxy.minimax-api-keys"
    ) {
        self.backingStore = ManagedProviderAPIKeyStore(
            descriptor: ManagedProviderAPIKeyDescriptor(
                authType: ProviderCatalog.managedMiniMaxProviderName,
                filePrefix: ProviderCatalog.managedMiniMaxProviderName,
                displayName: "MiniMax"
            ),
            directoryURL: directoryURL,
            fileManager: fileManager,
            queueLabel: queueLabel
        )
    }

    func save(
        apiKey: String,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> URL {
        try backingStore.save(apiKey: apiKey, createdAt: createdAt)
    }

    func loadActiveAPIKeys() -> ManagedProviderAPIKeyLoadResult {
        backingStore.loadActiveAPIKeys()
    }
}
