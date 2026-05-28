import Foundation

@main
struct CustomProviderCredentialStoreSpec {
    static func main() {
        let recorder = FailureRecorder()

        run("save and load custom provider credentials", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = CustomProviderCredentialStore(directoryURL: directoryURL)
                let saveResult = expectNoThrow(
                    recorder: recorder,
                    "saving a valid credential should succeed"
                ) {
                    try store.save(
                        providerID: "nvidia",
                        apiKey: "nvapi-1234567890abcdef",
                        label: "primary-nvidia-key"
                    )
                }

                guard let saveResult else { return }
                guard case .created(let createdRecord) = saveResult else {
                    recorder.recordFailure("first save should create a new credential file")
                    return
                }

                let loadResult = store.loadAll()
                expectEqual(loadResult.issues.count, 0, "valid credential files should load without issues", recorder: recorder)
                expectEqual(loadResult.records.count, 1, "one saved credential should be loaded", recorder: recorder)

                guard let record = loadResult.records.first else { return }
                expectEqual(record.providerID, "nvidia", "provider id should round-trip", recorder: recorder)
                expectEqual(record.apiKey, "nvapi-1234567890abcdef", "api key should round-trip", recorder: recorder)
                expectEqual(record.label, "primary-nvidia-key", "explicit labels should round-trip", recorder: recorder)
                expectEqual(record.isDisabled, false, "newly saved credentials should start enabled", recorder: recorder)
                expectEqual(
                    record.filePath.standardizedFileURL.path,
                    createdRecord.filePath.standardizedFileURL.path,
                    "loaded record should point to the saved file",
                    recorder: recorder
                )

                let permissions = filePermissions(at: record.filePath)
                expectEqual(permissions, 0o600, "credential files should be written with 0600 permissions", recorder: recorder)
            }
        }

        run("concurrent saves deduplicate the same logical credential", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = CustomProviderCredentialStore(directoryURL: directoryURL)
                let saveCount = 25
                let group = DispatchGroup()
                let queue = DispatchQueue.global(qos: .userInitiated)

                for _ in 0..<saveCount {
                    group.enter()
                    queue.async {
                        defer { group.leave() }
                        _ = try? store.save(
                            providerID: "nvidia",
                            apiKey: "nvapi-abcdef1234567890",
                            label: "toggle-target"
                        )
                    }
                }

                group.wait()

                let loadResult = store.loadAll()
                expectEqual(loadResult.issues.count, 0, "concurrent saves should not corrupt the credential file", recorder: recorder)
                expectEqual(loadResult.records.count, 1, "saving the same key repeatedly should produce one logical credential file", recorder: recorder)
                expectEqual(loadResult.records.first?.isDisabled, false, "duplicate saves should leave the logical credential enabled", recorder: recorder)
            }
        }

        run("saving an existing disabled credential re-enables it instead of creating a duplicate", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = CustomProviderCredentialStore(directoryURL: directoryURL)
                _ = try? store.save(providerID: "nvidia", apiKey: "nvapi-abcdef1234567890", label: "primary")
                _ = try? store.setDisabled(providerID: "nvidia", apiKey: "nvapi-abcdef1234567890", isDisabled: true)

                let saveResult = expectNoThrow(
                    recorder: recorder,
                    "saving an existing disabled credential should succeed"
                ) {
                    try store.save(providerID: "nvidia", apiKey: "nvapi-abcdef1234567890", label: "primary")
                }

                guard let saveResult else { return }
                guard case .reenabled = saveResult else {
                    recorder.recordFailure("saving an existing disabled credential should re-enable it")
                    return
                }

                let loadResult = store.loadAll()
                expectEqual(loadResult.records.count, 1, "re-enabling should not create a duplicate file", recorder: recorder)
                expectEqual(loadResult.records.first?.isDisabled, false, "the stored credential should be enabled again", recorder: recorder)
            }
        }

        run("malformed credential files are ignored gracefully", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = CustomProviderCredentialStore(directoryURL: directoryURL)

                let malformedFile = directoryURL.appendingPathComponent("openai-compat-bad.json")
                do {
                    try Data("{not-json".utf8).write(to: malformedFile, options: .atomic)
                } catch {
                    recorder.recordFailure("failed to seed malformed credential file: \(error.localizedDescription)")
                    return
                }

                _ = try? store.save(providerID: "nvidia", apiKey: "nvapi-good1234567890", label: "good-key")

                let loadResult = store.loadAll()
                expectEqual(loadResult.records.count, 1, "valid credentials should still load when a malformed file is present", recorder: recorder)
                expectEqual(loadResult.issues.count, 1, "malformed managed credential files should be reported as issues", recorder: recorder)
                expectContains(
                    loadResult.issues.first?.message ?? "",
                    "invalid JSON",
                    "malformed files should produce a readable invalid JSON issue",
                    recorder: recorder
                )
            }
        }

        run("delete removes stored credentials", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let store = CustomProviderCredentialStore(directoryURL: directoryURL)
                let saveResult = expectNoThrow(
                    recorder: recorder,
                    "saving a credential before delete should succeed"
                ) {
                    try store.save(providerID: "nvidia", apiKey: "nvapi-delete1234567890", label: "delete-me")
                }

                guard let saveResult else { return }
                guard case .created(let record) = saveResult else {
                    recorder.recordFailure("delete precondition should create a credential file")
                    return
                }

                let deletedCount = expectNoThrow(
                    recorder: recorder,
                    "deleting an existing credential should succeed"
                ) {
                    try store.delete(providerID: "nvidia", apiKey: "nvapi-delete1234567890")
                }
                guard let deletedCount else { return }
                expectEqual(deletedCount, 1, "delete should remove one matching credential file", recorder: recorder)

                expectEqual(FileManager.default.fileExists(atPath: record.filePath.path), false, "deleted credential file should be removed from disk", recorder: recorder)
                expectEqual(store.loadAll().records.count, 0, "deleted credentials should not be returned by loadAll", recorder: recorder)
            }
        }

        if recorder.failures == 0 {
            print("CustomProviderCredentialStoreSpec: all checks passed")
            Foundation.exit(EXIT_SUCCESS)
        }

        fputs("CustomProviderCredentialStoreSpec: \(recorder.failures) check(s) failed\n", stderr)
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

private func tryExpectNoThrow(
    recorder: FailureRecorder,
    _ message: String,
    _ body: () throws -> Void
) {
    do {
        try body()
    } catch {
        recorder.recordFailure("\(message): \(error.localizedDescription)")
    }
}

private func withTemporaryDirectory(recorder: FailureRecorder, _ body: (URL) -> Void) {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "custom-provider-credential-store-spec-\(UUID().uuidString)",
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
