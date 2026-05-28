import Foundation

@main
struct ConfigInputFingerprintSpec {
    static func main() {
        let recorder = FailureRecorder()

        run("fingerprint includes config and managed API key files only", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                writeText("port: 8317\n", to: directoryURL.appendingPathComponent("config.yaml"), recorder: recorder)
                writeText("{\"type\":\"zai\",\"api_key\":\"zai-1\"}\n", to: directoryURL.appendingPathComponent("zai-a.json"), recorder: recorder)
                writeText("{\"type\":\"openai-compat\",\"provider\":\"nvidia\",\"api_key\":\"nvapi-1\"}\n", to: directoryURL.appendingPathComponent("openai-compat-nvidia-a.json"), recorder: recorder)
                writeText("{\"type\":\"claude\"}\n", to: directoryURL.appendingPathComponent("claude.json"), recorder: recorder)
                writeText("generated: true\n", to: directoryURL.appendingPathComponent("merged-config.yaml"), recorder: recorder)

                let urls = ConfigInputFingerprint.relevantFileURLs(in: directoryURL)
                let names = urls.map(\.lastPathComponent)

                expectEqual(
                    names,
                    ["config.yaml", "openai-compat-nvidia-a.json", "zai-a.json"],
                    "only additive config and managed API key files should affect the fingerprint",
                    recorder: recorder
                )
            }
        }

        run("fingerprint changes when config.yaml changes", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let configURL = directoryURL.appendingPathComponent("config.yaml")
                writeText("port: 8317\n", to: configURL, recorder: recorder)
                let before = ConfigInputFingerprint.compute(in: directoryURL)
                writeText("port: 8318\n", to: configURL, recorder: recorder)
                let after = ConfigInputFingerprint.compute(in: directoryURL)

                expectNotEqual(
                    before,
                    after,
                    "editing config.yaml should produce a new config-input fingerprint",
                    recorder: recorder
                )
            }
        }

        run("fingerprint ignores merged-config churn", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                writeText("port: 8317\n", to: directoryURL.appendingPathComponent("config.yaml"), recorder: recorder)
                let before = ConfigInputFingerprint.compute(in: directoryURL)
                writeText("generated: one\n", to: directoryURL.appendingPathComponent("merged-config.yaml"), recorder: recorder)
                let afterWrite = ConfigInputFingerprint.compute(in: directoryURL)
                writeText("generated: two\n", to: directoryURL.appendingPathComponent("merged-config.yaml"), recorder: recorder)
                let afterRewrite = ConfigInputFingerprint.compute(in: directoryURL)

                expectEqual(before, afterWrite, "writing merged-config.yaml should not affect the fingerprint", recorder: recorder)
                expectEqual(before, afterRewrite, "rewriting merged-config.yaml should still be ignored", recorder: recorder)
            }
        }

        run("fingerprint changes when managed provider credentials change", recorder: recorder) {
            withTemporaryDirectory(recorder: recorder) { directoryURL in
                let credentialURL = directoryURL.appendingPathComponent("openai-compat-nvidia-a.json")
                writeText("{\"type\":\"openai-compat\",\"provider\":\"nvidia\",\"api_key\":\"nvapi-1\"}\n", to: credentialURL, recorder: recorder)
                let before = ConfigInputFingerprint.compute(in: directoryURL)
                writeText("{\"type\":\"openai-compat\",\"provider\":\"nvidia\",\"api_key\":\"nvapi-1\",\"disabled\":true}\n", to: credentialURL, recorder: recorder)
                let after = ConfigInputFingerprint.compute(in: directoryURL)

                expectNotEqual(
                    before,
                    after,
                    "changing a managed provider credential should trigger config re-evaluation",
                    recorder: recorder
                )
            }
        }

        if recorder.failures == 0 {
            print("ConfigInputFingerprintSpec: all checks passed")
            Foundation.exit(EXIT_SUCCESS)
        }

        fputs("ConfigInputFingerprintSpec: \(recorder.failures) check(s) failed\n", stderr)
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

private func expectNotEqual<T: Equatable>(
    _ lhs: @autoclosure () -> T,
    _ rhs: @autoclosure () -> T,
    _ message: String,
    recorder: FailureRecorder
) {
    let left = lhs()
    let right = rhs()
    guard left != right else {
        recorder.recordFailure("\(message): values unexpectedly matched: \(left)")
        return
    }
}

private func withTemporaryDirectory(recorder: FailureRecorder, _ body: (URL) -> Void) {
    let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
        "config-input-fingerprint-spec-\(UUID().uuidString)",
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

private func writeText(_ text: String, to url: URL, recorder: FailureRecorder) {
    do {
        try text.write(to: url, atomically: true, encoding: .utf8)
    } catch {
        recorder.recordFailure("failed to write \(url.lastPathComponent): \(error.localizedDescription)")
    }
}
