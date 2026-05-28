import Foundation

@main
struct ZAIAPIKeyStoreSpec {
    static func main() {
        let recorder = FailureRecorder()

        run("save and load active Z.AI API keys", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = ZAIAPIKeyStore(directoryURL: directoryURL)
                let filePath = expectNoThrow(
                    recorder: recorder,
                    "saving a valid Z.AI API key should succeed"
                ) {
                    try store.save(apiKey: "zai-1234567890abcdef")
                }

                guard let filePath else { return }

                let loadResult = store.loadActiveAPIKeys()
                expectEqual(loadResult.issues.count, 0, "valid Z.AI key files should load without issues", recorder: recorder)
                expectEqual(loadResult.apiKeys, ["zai-1234567890abcdef"], "saved Z.AI key should be returned as active", recorder: recorder)
                expectEqual(filePermissions(at: filePath), 0o600, "Z.AI key files should be written with 0600 permissions", recorder: recorder)
            }
        }

        run("disabled Z.AI API keys are excluded from the active runtime set", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = ZAIAPIKeyStore(directoryURL: directoryURL)

                let disabledFile = directoryURL.appendingPathComponent("zai-disabled.json")
                let disabledJSON: [String: Any] = [
                    "type": "zai",
                    "email": "masked@example.com",
                    "api_key": "zai-disabled",
                    "disabled": true
                ]

                do {
                    let data = try JSONSerialization.data(withJSONObject: disabledJSON, options: [.prettyPrinted])
                    try data.write(to: disabledFile, options: .atomic)
                } catch {
                    recorder.recordFailure("failed to seed disabled Z.AI key file: \(error.localizedDescription)")
                    return
                }

                _ = try? store.save(apiKey: "zai-enabled")

                let loadResult = store.loadActiveAPIKeys()
                expectEqual(loadResult.issues.count, 0, "disabled Z.AI key files should not be treated as malformed", recorder: recorder)
                expectEqual(loadResult.apiKeys, ["zai-enabled"], "disabled Z.AI keys should be excluded from the active key set", recorder: recorder)
            }
        }

        run("malformed managed Z.AI key files are ignored gracefully", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = ZAIAPIKeyStore(directoryURL: directoryURL)

                let malformedFile = directoryURL.appendingPathComponent("zai-bad.json")
                do {
                    try Data("{not-json".utf8).write(to: malformedFile, options: .atomic)
                } catch {
                    recorder.recordFailure("failed to seed malformed Z.AI key file: \(error.localizedDescription)")
                    return
                }

                _ = try? store.save(apiKey: "zai-good")

                let loadResult = store.loadActiveAPIKeys()
                expectEqual(loadResult.apiKeys, ["zai-good"], "valid Z.AI keys should still load when a malformed file is present", recorder: recorder)
                expectEqual(loadResult.issues.count, 1, "malformed managed Z.AI files should be reported as issues", recorder: recorder)
                expectContains(
                    loadResult.issues.first?.message ?? "",
                    "invalid JSON",
                    "malformed Z.AI files should produce a readable invalid JSON issue",
                    recorder: recorder
                )
            }
        }

        if recorder.failures == 0 {
            print("ZAIAPIKeyStoreSpec: all checks passed")
            Foundation.exit(EXIT_SUCCESS)
        }

        fputs("ZAIAPIKeyStoreSpec: \(recorder.failures) check(s) failed\n", stderr)
        Foundation.exit(EXIT_FAILURE)
    }
}

private final class FailureRecorder {
    var failures = 0

    func recordFailure(_ message: String) {
        failures += 1
        fputs("  - \(message)\n", stderr)
    }
}

private func run(_ name: String, recorder: FailureRecorder, _ body: () -> Void) {
    let startingFailures = recorder.failures
    body()
    let status = recorder.failures == startingFailures ? "PASS" : "FAIL"
    print("[\(status)] \(name)")
}

private func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: T,
    _ message: String,
    recorder: FailureRecorder
) {
    let value = actual()
    guard value == expected else {
        recorder.recordFailure("\(message): expected \(expected), got \(value)")
        return
    }
}

private func expectContains(
    _ actual: @autoclosure () -> String,
    _ expectedSubstring: String,
    _ message: String,
    recorder: FailureRecorder
) {
    let value = actual()
    guard value.contains(expectedSubstring) else {
        recorder.recordFailure("\(message): expected substring \(expectedSubstring) in \(value)")
        return
    }
}

private func expectNoThrow<T>(
    recorder: FailureRecorder,
    _ message: String,
    _ body: () throws -> T
) -> T? {
    do {
        return try body()
    } catch {
        recorder.recordFailure("\(message): \(error.localizedDescription)")
        return nil
    }
}

private func withTemporaryDirectory(recorder: FailureRecorder, _ body: (URL) -> Void) {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "zai-api-key-store-spec-\(UUID().uuidString)",
        isDirectory: true
    )

    do {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    } catch {
        recorder.recordFailure("failed to create temporary directory: \(error.localizedDescription)")
        return
    }

    defer {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    body(directoryURL)
}

private func filePermissions(at filePath: URL) -> Int? {
    let attributes = try? FileManager.default.attributesOfItem(atPath: filePath.path)
    return attributes?[.posixPermissions] as? Int
}
