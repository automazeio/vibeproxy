import Foundation
import Combine
import Darwin

enum GrokLoginState: Equatable {
    case starting
    case awaitingAuthorization(url: URL?, code: String?)
    case authenticated(account: String)
    case failed(message: String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .starting, .awaitingAuthorization: return true
        default: return false
        }
    }
}

/// Parses the stock CLIProxyAPI xAI device-flow output. Keep byte buffers separate:
/// both UTF-8 characters and lines can span reads, and stderr can interleave stdout.
struct GrokLoginOutput {
    enum Stream { case stdout, stderr }
    private var stdout = Data()
    private var stderr = Data()
    private(set) var verificationURL: URL?
    private(set) var userCode: String?
    private(set) var savedPath: String?
    private(set) var failureMessage: String?

    mutating func append(_ data: Data, from stream: Stream) {
        let lines: [String]
        switch stream {
        case .stdout: stdout.append(data); lines = Self.takeLines(&stdout)
        case .stderr: stderr.append(data); lines = Self.takeLines(&stderr)
        }
        for line in lines { consume(line) }
    }

    // Return complete lines before mutating parser fields (avoids overlapping access).
    private static func takeLines(_ buffer: inout Data) -> [String] {
        var lines: [String] = []
        while let newline = buffer.firstIndex(of: 10) {
            lines.append(String(decoding: buffer[..<newline], as: UTF8.self))
            buffer.removeSubrange(...newline)
        }
        // Login output is small. Bound an unexpected unterminated line.
        if buffer.count > 64 * 1024 { buffer.removeAll() }
        return lines
    }

    mutating func finish() {
        let tails = [stdout, stderr]
        stdout.removeAll(); stderr.removeAll()
        for data in tails where !data.isEmpty {
            consume(String(decoding: data, as: UTF8.self))
        }
    }

    private mutating func consume(_ rawLine: String) {
        let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: line), url.scheme == "https",
           let host = url.host?.lowercased(),
           host == "x.ai" || host.hasSuffix(".x.ai"),
           url.user == nil, url.password == nil {
            verificationURL = url
        }
        if line.hasPrefix("Then enter this code: ") {
            let code = String(line.dropFirst("Then enter this code: ".count))
                .trimmingCharacters(in: .whitespaces)
            if !code.isEmpty { userCode = code }
        }
        if line.hasPrefix("Authentication saved to ") {
            savedPath = String(line.dropFirst("Authentication saved to ".count))
        }
        // Do not expose raw subprocess diagnostics: they may contain credentials.
        let lower = line.lowercased()
        if lower.contains("xai authentication failed") {
            if lower.contains("denied") {
                failureMessage = "Authorization was denied. Sign in again to retry."
            } else if lower.contains("expired") {
                failureMessage = "The device code expired. Sign in again for a new code."
            } else if lower.contains("timeout") || lower.contains("request failed") || lower.contains("connection") {
                failureMessage = "Could not reach xAI. Check your connection and proxy settings, then retry."
            } else {
                failureMessage = "xAI authentication failed. Check your account's Grok Build access and retry."
            }
        }
    }

    func result(exitCode: Int32, authDirectory: URL) -> GrokLoginState {
        if let failureMessage { return .failed(message: failureMessage) }
        guard exitCode == 0 else {
            return .failed(message: "The sign-in process stopped unexpectedly (exit \(exitCode)). Please retry.")
        }
        // Upstream prints an early success message before persisting credentials.
        // Require the *saved* message and recognize the resulting account on disk.
        if let savedPath {
            let file = URL(fileURLWithPath: savedPath).standardizedFileURL.resolvingSymlinksInPath()
            let directory = authDirectory.standardizedFileURL.resolvingSymlinksInPath()
            if file.deletingLastPathComponent() == directory, file.pathExtension == "json",
               let data = try? Data(contentsOf: file),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               (json["type"] as? String)?.lowercased() == "xai",
               let token = json["access_token"] as? String,
               !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let email = (json["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                return .authenticated(account: email.flatMap { $0.isEmpty ? nil : $0 } ?? file.lastPathComponent)
            }
        }
        return .failed(message: "Sign-in ended without a saved Grok account. Please retry.")
    }
}

/// Owns only the process launched for this login. All state changes are on main;
/// blocking pipe reads run in the background and are drained before completion.
final class GrokLoginController: ObservableObject {
    @Published private(set) var state: GrokLoginState = .cancelled

    private final class Attempt {
        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        let completion = DispatchGroup()
        let authDirectory: URL
        var parser = GrokLoginOutput()

        init(authDirectory: URL) { self.authDirectory = authDirectory }
    }

    private var attempt: Attempt?

    func start(executableURL: URL, arguments: [String], authDirectory: URL) {
        dispatchPrecondition(condition: .onQueue(.main))
        cancel()
        state = .starting
        let current = Attempt(authDirectory: authDirectory)
        attempt = current
        let process = current.process
        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = current.output
        process.standardError = current.errors
        process.standardInput = FileHandle.nullDevice
        let completion = current.completion
        completion.enter()
        process.terminationHandler = { _ in completion.leave() }
        do {
            try process.run()
        } catch {
            process.terminationHandler = nil
            completion.leave()
            for pipe in [current.output, current.errors] {
                try? pipe.fileHandleForReading.close()
                try? pipe.fileHandleForWriting.close()
            }
            attempt = nil
            state = .failed(message: "Could not start Grok sign-in. Check that the bundled CLIProxyAPI executable is available.")
            return
        }
        read(current.output, stream: .stdout, attempt: current)
        read(current.errors, stream: .stderr, attempt: current)
        completion.notify(queue: .main) { [weak self] in
            guard let self, self.attempt === current else { return }
            current.parser.finish()
            self.attempt = nil
            self.state = current.parser.result(exitCode: process.terminationStatus, authDirectory: current.authDirectory)
            if case .authenticated = self.state {
                NotificationCenter.default.post(name: .authDirectoryChanged, object: nil)
            }
        }
    }

    private func read(_ pipe: Pipe, stream: GrokLoginOutput.Stream, attempt current: Attempt) {
        current.completion.enter()
        try? pipe.fileHandleForWriting.close()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            defer {
                try? pipe.fileHandleForReading.close()
                current.completion.leave()
            }
            while true {
                let data = pipe.fileHandleForReading.availableData
                guard !data.isEmpty else { break }
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.attempt === current else { return }
                    current.parser.append(data, from: stream)
                    if current.parser.verificationURL != nil || current.parser.userCode != nil {
                        self.state = .awaitingAuthorization(url: current.parser.verificationURL, code: current.parser.userCode)
                    }
                }
            }
        }
    }

    func fail(_ message: String) {
        cancel()
        state = .failed(message: message)
    }

    func cancel() {
        guard let current = attempt else { return }
        attempt = nil
        state = .cancelled
        Self.terminate(current.process)
    }

    private static func terminate(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
        }
    }

    deinit {
        if let attempt { Self.terminate(attempt.process) }
    }
}
