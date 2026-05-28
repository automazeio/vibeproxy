import Foundation

struct CustomProviderCredentialRecord: Equatable {
    let providerID: String
    let apiKey: String
    let label: String
    let filePath: URL
    let isDisabled: Bool
}

struct CustomProviderCredentialLoadIssue: Equatable {
    let filePath: URL
    let message: String
}

struct CustomProviderCredentialLoadResult: Equatable {
    let records: [CustomProviderCredentialRecord]
    let issues: [CustomProviderCredentialLoadIssue]
}

enum CustomProviderCredentialSaveResult: Equatable {
    case created(CustomProviderCredentialRecord)
    case alreadyPresent(CustomProviderCredentialRecord)
    case reenabled(CustomProviderCredentialRecord)
}

enum CustomProviderCredentialStoreError: LocalizedError {
    case failedToCreateDirectory(String)
    case failedToSerializeCredential(String)
    case failedToWriteCredential(String)
    case failedToReadCredential(String)
    case invalidCredentialJSON(String)
    case malformedCredential(String)
    case failedToDeleteCredential(String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory(let message),
             .failedToSerializeCredential(let message),
             .failedToWriteCredential(let message),
             .failedToReadCredential(let message),
             .invalidCredentialJSON(let message),
             .malformedCredential(let message),
             .failedToDeleteCredential(let message):
            return message
        }
    }
}

final class CustomProviderCredentialStore {
    static let authType = "openai-compat"

    private let directoryURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue
    private let jsonWriteOptions: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]

    init(
        directoryURL: URL,
        fileManager: FileManager = .default,
        queueLabel: String = "io.automaze.vibeproxy.custom-provider-credentials"
    ) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
        self.queue = DispatchQueue(label: queueLabel, qos: .userInitiated)
    }

    func save(
        providerID: String,
        apiKey: String,
        label: String? = nil,
        createdAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> CustomProviderCredentialSaveResult {
        try queue.sync {
            try ensureDirectoryExists()

            let existingRecords = loadAllUnlocked().records.filter { record in
                record.providerID == providerID && record.apiKey == apiKey
            }
            if !existingRecords.isEmpty {
                if existingRecords.contains(where: { $0.isDisabled }) {
                    let updatedRecords = try setDisabledUnlocked(
                        providerID: providerID,
                        apiKey: apiKey,
                        isDisabled: false
                    )
                    return .reenabled(preferredRecord(from: updatedRecords))
                }
                return .alreadyPresent(preferredRecord(from: existingRecords))
            }

            let filename = "openai-compat-\(sanitizeFilenameComponent(providerID))-\(UUID().uuidString.prefix(8)).json"
            let filePath = directoryURL.appendingPathComponent(filename)
            let authData = credentialJSONObject(
                providerID: providerID,
                apiKey: apiKey,
                label: label,
                createdAt: createdAt,
                isDisabled: false
            )
            try writeCredentialJSONUnlocked(authData, to: filePath, providerID: providerID)

            return .created(try record(from: authData, filePath: filePath))
        }
    }

    func delete(providerID: String, apiKey: String) throws -> Int {
        try queue.sync {
            let matchingRecords = loadAllUnlocked().records.filter { record in
                record.providerID == providerID && record.apiKey == apiKey
            }
            guard !matchingRecords.isEmpty else {
                throw CustomProviderCredentialStoreError.failedToDeleteCredential(
                    "No stored credential was found for provider \(providerID)."
                )
            }

            for record in matchingRecords {
                do {
                    try fileManager.removeItem(at: record.filePath)
                } catch {
                    throw CustomProviderCredentialStoreError.failedToDeleteCredential(
                        "Failed to delete credential file at \(record.filePath.path): \(error.localizedDescription)"
                    )
                }
            }

            return matchingRecords.count
        }
    }

    func setDisabled(providerID: String, apiKey: String, isDisabled: Bool) throws {
        try queue.sync {
            _ = try setDisabledUnlocked(providerID: providerID, apiKey: apiKey, isDisabled: isDisabled)
        }
    }

    func loadAll() -> CustomProviderCredentialLoadResult {
        queue.sync {
            loadAllUnlocked()
        }
    }

    private func loadRecord(at filePath: URL) throws -> CustomProviderCredentialRecord {
        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw CustomProviderCredentialStoreError.failedToReadCredential(
                "Failed to read credential file at \(filePath.path): \(error.localizedDescription)"
            )
        }

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CustomProviderCredentialStoreError.invalidCredentialJSON(
                "Credential file at \(filePath.path) contains invalid JSON: \(error.localizedDescription)"
            )
        }

        guard let json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) must contain a JSON object."
            )
        }

        return try record(from: json, filePath: filePath)
    }

    private func record(from json: [String: Any], filePath: URL) throws -> CustomProviderCredentialRecord {
        guard (json["type"] as? String) == Self.authType else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) has an unexpected type."
            )
        }
        guard let providerID = json["provider"] as? String, !providerID.isEmpty else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) is missing a provider."
            )
        }
        guard let apiKey = json["api_key"] as? String, !apiKey.isEmpty else {
            throw CustomProviderCredentialStoreError.malformedCredential(
                "Credential file at \(filePath.path) is missing an api_key."
            )
        }

        return CustomProviderCredentialRecord(
            providerID: providerID,
            apiKey: apiKey,
            label: (json["label"] as? String) ?? maskAPIKey(apiKey),
            filePath: filePath,
            isDisabled: json["disabled"] as? Bool ?? false
        )
    }

    private func ensureDirectoryExists() throws {
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            throw CustomProviderCredentialStoreError.failedToCreateDirectory(
                "Failed to create auth directory at \(directoryURL.path): \(error.localizedDescription)"
            )
        }
    }

    private func loadAllUnlocked() -> CustomProviderCredentialLoadResult {
        guard let files = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ) else {
            return CustomProviderCredentialLoadResult(records: [], issues: [])
        }

        var records: [CustomProviderCredentialRecord] = []
        var issues: [CustomProviderCredentialLoadIssue] = []

        for file in files
            .filter({ isManagedCredentialFile($0) })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            do {
                records.append(try loadRecord(at: file))
            } catch let error as CustomProviderCredentialStoreError {
                issues.append(
                    CustomProviderCredentialLoadIssue(
                        filePath: file,
                        message: error.localizedDescription
                    )
                )
            } catch {
                issues.append(
                    CustomProviderCredentialLoadIssue(
                        filePath: file,
                        message: "Unexpected error while loading \(file.path): \(error.localizedDescription)"
                    )
                )
            }
        }

        return CustomProviderCredentialLoadResult(records: records, issues: issues)
    }

    private func setDisabledUnlocked(
        providerID: String,
        apiKey: String,
        isDisabled: Bool
    ) throws -> [CustomProviderCredentialRecord] {
        let matchingRecords = loadAllUnlocked().records.filter { record in
            record.providerID == providerID && record.apiKey == apiKey
        }
        guard !matchingRecords.isEmpty else {
            throw CustomProviderCredentialStoreError.failedToWriteCredential(
                "No stored credential was found for provider \(providerID)."
            )
        }

        var updatedRecords: [CustomProviderCredentialRecord] = []
        updatedRecords.reserveCapacity(matchingRecords.count)

        for credentialRecord in matchingRecords {
            let data: Data
            do {
                data = try Data(contentsOf: credentialRecord.filePath)
            } catch {
                throw CustomProviderCredentialStoreError.failedToReadCredential(
                    "Failed to read credential file at \(credentialRecord.filePath.path): \(error.localizedDescription)"
                )
            }

            let jsonObject: Any
            do {
                jsonObject = try JSONSerialization.jsonObject(with: data)
            } catch {
                throw CustomProviderCredentialStoreError.invalidCredentialJSON(
                    "Credential file at \(credentialRecord.filePath.path) contains invalid JSON: \(error.localizedDescription)"
                )
            }

            guard var json = ConfigComposer.stringKeyedDictionary(jsonObject) else {
                throw CustomProviderCredentialStoreError.malformedCredential(
                    "Credential file at \(credentialRecord.filePath.path) must contain a JSON object."
                )
            }

            _ = try record(from: json, filePath: credentialRecord.filePath)
            json["disabled"] = isDisabled
            try writeCredentialJSONUnlocked(json, to: credentialRecord.filePath, providerID: providerID)
            updatedRecords.append(try record(from: json, filePath: credentialRecord.filePath))
        }

        return updatedRecords.sorted { lhs, rhs in
            lhs.filePath.lastPathComponent < rhs.filePath.lastPathComponent
        }
    }

    private func credentialJSONObject(
        providerID: String,
        apiKey: String,
        label: String?,
        createdAt: String,
        isDisabled: Bool
    ) -> [String: Any] {
        var authData: [String: Any] = [
            "type": Self.authType,
            "provider": providerID,
            "label": label ?? maskAPIKey(apiKey),
            "api_key": apiKey,
            "created": createdAt
        ]
        if isDisabled {
            authData["disabled"] = true
        }
        return authData
    }

    private func writeCredentialJSONUnlocked(_ json: [String: Any], to filePath: URL, providerID: String) throws {
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: json, options: jsonWriteOptions)
        } catch {
            throw CustomProviderCredentialStoreError.failedToSerializeCredential(
                "Failed to serialize credential for \(providerID): \(error.localizedDescription)"
            )
        }

        do {
            try jsonData.write(to: filePath, options: Data.WritingOptions.atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: filePath.path)
        } catch {
            throw CustomProviderCredentialStoreError.failedToWriteCredential(
                "Failed to write credential file at \(filePath.path): \(error.localizedDescription)"
            )
        }
    }

    private func preferredRecord(from records: [CustomProviderCredentialRecord]) -> CustomProviderCredentialRecord {
        records.sorted { lhs, rhs in
            if lhs.isDisabled != rhs.isDisabled {
                return !lhs.isDisabled
            }

            let labelComparison = lhs.label.localizedCaseInsensitiveCompare(rhs.label)
            if labelComparison != .orderedSame {
                return labelComparison == .orderedAscending
            }

            return lhs.filePath.lastPathComponent < rhs.filePath.lastPathComponent
        }.first!
    }

    private func isManagedCredentialFile(_ filePath: URL) -> Bool {
        filePath.pathExtension == "json" && filePath.lastPathComponent.hasPrefix("openai-compat-")
    }

    private func sanitizeFilenameComponent(_ value: String) -> String {
        let sanitized = value.replacingOccurrences(
            of: "[^A-Za-z0-9._-]+",
            with: "-",
            options: .regularExpression
        )
        return sanitized.isEmpty ? "provider" : sanitized
    }

    private func maskAPIKey(_ apiKey: String) -> String {
        guard apiKey.count > 12 else {
            return apiKey
        }
        return String(apiKey.prefix(8)) + "..." + String(apiKey.suffix(4))
    }
}
