import XCTest
import Combine
import AppKit
import SwiftUI
@testable import CLIProxyMenuBar

final class GrokLoginTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: directory)
    }

    func testSplitBytesAndInterleavedBrowserWarningKeepDeviceDetails() {
        var parser = GrokLoginOutput()
        let output = "To authenticate, please visit:\nhttps://auth.x.ai/device?code=ABCD\nThen enter this code: ABCD-EFGH\n"
        for byte in output.utf8 {
            parser.append(Data([byte]), from: .stdout)
            parser.append(Data("Failed to open browser automatically\n".utf8), from: .stderr)
        }
        XCTAssertEqual(parser.verificationURL?.absoluteString, "https://auth.x.ai/device?code=ABCD")
        XCTAssertEqual(parser.userCode, "ABCD-EFGH")
        XCTAssertNil(parser.failureMessage)
    }

    func testRejectsUntrustedOrNonHTTPSVerificationLinks() {
        for link in ["http://auth.x.ai/device", "https://x.ai.example.com/device", "https://user:password@auth.x.ai/device"] {
            var parser = GrokLoginOutput()
            parser.append(Data("\(link)\n".utf8), from: .stdout)
            XCTAssertNil(parser.verificationURL)
        }
    }

    func testSuccessRequiresSavedRecognizedCredentialEvenWithZeroExit() throws {
        let file = try credential()
        var parser = GrokLoginOutput()
        parser.append(Data("xAI authentication successful\n".utf8), from: .stdout)
        assertFailed(parser.result(exitCode: 0, authDirectory: directory))
        parser.append(Data("Authentication saved to \(file.path)".utf8), from: .stdout)
        parser.finish()
        XCTAssertEqual(parser.result(exitCode: 0, authDirectory: directory), .authenticated(account: "test@example.com"))
        assertFailed(parser.result(exitCode: 1, authDirectory: directory))
    }

    func testSavedCredentialMustBeXAIWithTokenInsideAuthDirectory() throws {
        let file = try credential()
        var parser = GrokLoginOutput()
        parser.append(Data("Authentication saved to \(file.path)\n".utf8), from: .stdout)
        assertFailed(parser.result(exitCode: 0, authDirectory: directory.appendingPathComponent("elsewhere")))
        for json in ["{}", "{\"type\":\"xai\",\"access_token\":\" \"}", "{\"type\":\"codex\",\"access_token\":\"test\"}", "invalid"] {
            try Data(json.utf8).write(to: file)
            assertFailed(parser.result(exitCode: 0, authDirectory: directory))
        }
    }

    func testLateAuthFailureOverridesEarlySuccessAndDoesNotExposeSecrets() throws {
        let file = try credential()
        for (diagnostic, expected) in [
            ("xai device authorization denied", "denied"),
            ("xai device code expired", "expired"),
            ("xai discovery: request failed", "connection"),
            ("access_token=secret", "failed")
        ] {
            var parser = GrokLoginOutput()
            parser.append(Data("Authentication saved to \(file.path)\n".utf8), from: .stdout)
            parser.append(Data("[error] xAI authentication failed: \(diagnostic)".utf8), from: .stderr)
            parser.finish()
            guard case .failed(let message) = parser.result(exitCode: 0, authDirectory: directory) else {
                return XCTFail("Failure must override success")
            }
            XCTAssertTrue(message.contains(expected))
            XCTAssertFalse(message.contains("secret"))
        }
    }

    func testRealProcessDrainsBothPipesBeforeReportingSavedAccount() throws {
        let login = GrokLoginController()
        let done = expectation(description: "credential recognized")
        let waiting = expectation(description: "device details before exit")
        var observedWaiting = false
        let subscription = login.$state.sink { state in
            if case .awaitingAuthorization(let url, let code) = state, url != nil, code == "ABCD-EFGH", !observedWaiting {
                observedWaiting = true
                waiting.fulfill()
            }
            if case .authenticated(let account) = state {
                XCTAssertEqual(account, "test@example.com")
                done.fulfill()
            }
        }
        let script = """
        printf 'https://auth.x.ai/device\nThen enter this '
        sleep 0.1
        printf 'code: ABCD-EFGH\n'
        printf 'Failed to open browser automatically\n' >&2
        sleep 0.1
        printf '%s' '{"type":"xai","access_token":"synthetic-test-token","email":"test@example.com"}' > "$1/xai-test.json"
        printf 'Authentication saved to %s/xai-test.json\n' "$1"
        """
        login.start(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", script, "test", directory.path], authDirectory: directory)
        wait(for: [waiting, done], timeout: 5)
        withExtendedLifetime(subscription) {}
    }

    func testProcessZeroExitWithDelayedErrorIsFailure() {
        let login = GrokLoginController()
        let done = expectation(description: "delayed denial")
        let subscription = login.$state.sink { state in
            if case .failed(let message) = state {
                XCTAssertTrue(message.contains("denied"))
                done.fulfill()
            }
        }
        login.start(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 0.1; printf 'xAI authentication failed: access denied' >&2; exit 0"], authDirectory: directory)
        wait(for: [done], timeout: 5)
        withExtendedLifetime(subscription) {}
    }

    func testCancellationAndRetryIgnorePreviousProcessCompletion() {
        let login = GrokLoginController()
        login.start(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "exec sleep 20"], authDirectory: directory)
        login.cancel()
        XCTAssertEqual(login.state, .cancelled)
        let done = expectation(description: "retry failure")
        let subscription = login.$state.sink { state in
            if case .failed(let message) = state {
                XCTAssertTrue(message.contains("expired"))
                done.fulfill()
            }
        }
        login.start(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "sleep 0.2; printf 'xAI authentication failed: code expired\n' >&2"], authDirectory: directory)
        wait(for: [done], timeout: 5)
        withExtendedLifetime(subscription) {}
    }

    func testMissingExecutableIsActionableFailure() {
        let login = GrokLoginController()
        login.start(executableURL: directory.appendingPathComponent("missing"), arguments: [], authDirectory: directory)
        assertFailed(login.state)
        XCTAssertFalse(login.state.isActive)
    }

    @MainActor
    func testDeviceCodeSheetFitsAndRendersInBothAppearances() throws {
        _ = NSApplication.shared
        let login = GrokLoginController()
        let waiting = expectation(description: "device code ready for preview")
        var ready = false
        let subscription = login.$state.sink { state in
            if case .awaitingAuthorization(_, let code) = state, code != nil, !ready {
                ready = true
                waiting.fulfill()
            }
        }
        login.start(executableURL: URL(fileURLWithPath: "/bin/sh"), arguments: ["-c", "printf 'https://auth.x.ai/device?user_code=ABCD-EFGH\\nThen enter this code: ABCD-EFGH\\n'; exec sleep 20"], authDirectory: directory)
        defer { login.cancel() }
        wait(for: [waiting], timeout: 5)
        // Keep exported previews optional for normal local test runs.
        for (name, appearance) in [("light", NSAppearance.Name.aqua), ("dark", .darkAqua)] {
            let view = NSHostingView(rootView: GrokLoginSheet(login: login, retry: {}))
            view.appearance = NSAppearance(named: appearance)
            let size = view.fittingSize
            XCTAssertEqual(size.width, 440, accuracy: 1)
            XCTAssertLessThan(size.height, 600)
            XCTAssertGreaterThan(size.height, 200)
            view.setFrameSize(size)
            view.layoutSubtreeIfNeeded()
            if let output = ProcessInfo.processInfo.environment["GROK_PREVIEW_DIRECTORY"] {
                let target = URL(fileURLWithPath: output)
                try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
                let bitmap = try XCTUnwrap(view.bitmapImageRepForCachingDisplay(in: view.bounds))
                view.cacheDisplay(in: view.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: target.appendingPathComponent("grok-login-\(name).png"))
            }
        }
        withExtendedLifetime(subscription) {}
    }

    private func credential() throws -> URL {
        let file = directory.appendingPathComponent("xai-test.json")
        try Data("{\"type\":\"xai\",\"access_token\":\"synthetic-test-token\",\"email\":\"test@example.com\"}".utf8).write(to: file)
        return file
    }

    private func assertFailed(_ state: GrokLoginState, file: StaticString = #filePath, line: UInt = #line) {
        if case .failed = state { return }
        XCTFail("Expected failure, got \(state)", file: file, line: line)
    }
}
