import Foundation
#if canImport(Darwin)
import Darwin
#endif

enum ClaudeSetupTokenStoreError: LocalizedError, Equatable {
    case emptyLabel
    case invalidToken
    case duplicateToken
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyLabel:
            return "Enter an account name."
        case .invalidToken:
            return "Enter a Claude Code setup token that starts with sk-ant-oat01-."
        case .duplicateToken:
            return "That setup token is already saved."
        case .writeFailed:
            return "Could not save the setup token."
        }
    }
}

struct ClaudeSetupTokenStore {
    static let tokenPrefix = "sk-ant-oat01-"
    private static let minTokenSuffixLength = 8
    private static let tokenSuffixCharacterSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-")

    let authDirectory: URL
    let fileManager: FileManager

    init(
        authDirectory: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cli-proxy-api", isDirectory: true),
        fileManager: FileManager = .default
    ) {
        self.authDirectory = authDirectory
        self.fileManager = fileManager
    }

    @discardableResult
    func save(label rawLabel: String, setupToken rawToken: String) throws -> URL {
        let label = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { throw ClaudeSetupTokenStoreError.emptyLabel }

        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isValidSetupToken(token) else {
            throw ClaudeSetupTokenStoreError.invalidToken
        }

        try fileManager.createDirectory(
            at: authDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: authDirectory.path)
        try ensureNoDuplicate(token: token)

        let credential: [String: Any] = [
            "type": "claude",
            "access_token": token,
            "refresh_token": "",
            "is_setup_token": true,
            "skip_account_profile": true,
            "label": label,
            "disabled": false
        ]
        let data = try JSONSerialization.data(withJSONObject: credential, options: [.prettyPrinted, .sortedKeys])
        let destination = try nextAvailableCredentialURL(for: label)
        try writeCredential(data, to: destination)
        return destination
    }

    private static func isValidSetupToken(_ token: String) -> Bool {
        guard token.hasPrefix(tokenPrefix) else { return false }
        let suffix = String(token.dropFirst(tokenPrefix.count))
        guard suffix.count >= minTokenSuffixLength else { return false }
        return suffix.unicodeScalars.allSatisfy { tokenSuffixCharacterSet.contains($0) }
    }

    private func ensureNoDuplicate(token: String) throws {
        let files = try fileManager.contentsOfDirectory(at: authDirectory, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["type"] as? String == "claude",
                  json["access_token"] as? String == token else {
                continue
            }
            throw ClaudeSetupTokenStoreError.duplicateToken
        }
    }

    private func nextAvailableCredentialURL(for label: String) throws -> URL {
        let stem = "claude-\(Self.safeFilenameStem(for: label))"
        var candidate = authDirectory.appendingPathComponent("\(stem).json")
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = authDirectory.appendingPathComponent("\(stem)-\(suffix).json")
            suffix += 1
        }
        return candidate
    }

    static func safeFilenameStem(for label: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        let scalars = label.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let collapsed = String(scalars).split(separator: "-").joined(separator: "-")
        let trimmed = collapsed.trimmingCharacters(in: CharacterSet(charactersIn: ".-_"))
        return String((trimmed.isEmpty ? "setup-token" : trimmed).prefix(80))
    }

    private func writeCredential(_ data: Data, to destination: URL) throws {
        let tempURL = authDirectory.appendingPathComponent(".\(destination.lastPathComponent).tmp-\(UUID().uuidString)")
        do {
            #if canImport(Darwin)
            let fd = open(tempURL.path, O_WRONLY | O_CREAT | O_EXCL, S_IRUSR | S_IWUSR)
            guard fd >= 0 else { throw ClaudeSetupTokenStoreError.writeFailed("open") }
            defer { close(fd) }
            let wroteAllBytes = data.withUnsafeBytes { rawBuffer -> Bool in
                guard let baseAddress = rawBuffer.baseAddress else { return data.isEmpty }
                var offset = 0
                while offset < rawBuffer.count {
                    let written = write(fd, baseAddress.advanced(by: offset), rawBuffer.count - offset)
                    if written <= 0 { return false }
                    offset += written
                }
                return true
            }
            guard fsync(fd) == 0 else { throw ClaudeSetupTokenStoreError.writeFailed("fsync") }
            guard wroteAllBytes else { throw ClaudeSetupTokenStoreError.writeFailed("write") }
            #else
            try data.write(to: tempURL, options: .withoutOverwriting)
            #endif
            try fileManager.moveItem(at: tempURL, to: destination)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destination.path)
        } catch {
            try? fileManager.removeItem(at: tempURL)
            if let storeError = error as? ClaudeSetupTokenStoreError { throw storeError }
            throw ClaudeSetupTokenStoreError.writeFailed(error.localizedDescription)
        }
    }
}
