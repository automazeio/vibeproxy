import Foundation
import XCTest
@testable import CLIProxyMenuBar

final class ConfigInputFingerprintTests: XCTestCase {
    func testRelevantFilesIncludeConfigAndManagedCredentialsOnly() throws {
        try TestSupport.withTemporaryDirectory(prefix: "config-input-fingerprint") { directoryURL in
            try TestSupport.write("port: 8317\n", to: directoryURL.appendingPathComponent("config.yaml"))
            try TestSupport.write(#"{"type":"zai","api_key":"zai-1"}"#, to: directoryURL.appendingPathComponent("zai-a.json"))
            try TestSupport.write(#"{"type":"openai-compat","provider":"nvidia","api_key":"nvapi-1"}"#, to: directoryURL.appendingPathComponent("openai-compat-nvidia-a.json"))
            try TestSupport.write(#"{"type":"claude"}"#, to: directoryURL.appendingPathComponent("claude.json"))
            try TestSupport.write("generated: true\n", to: directoryURL.appendingPathComponent("merged-config.yaml"))

            let names = ConfigInputFingerprint.relevantFileURLs(in: directoryURL).map(\.lastPathComponent)

            XCTAssertEqual(names, ["config.yaml", "openai-compat-nvidia-a.json", "zai-a.json"])
        }
    }

    func testFingerprintChangesWhenConfigChanges() throws {
        try TestSupport.withTemporaryDirectory(prefix: "config-input-fingerprint") { directoryURL in
            let configURL = directoryURL.appendingPathComponent("config.yaml")
            try TestSupport.write("port: 8317\n", to: configURL)
            let before = ConfigInputFingerprint.compute(in: directoryURL)

            try TestSupport.write("port: 8318\n", to: configURL)

            XCTAssertNotEqual(ConfigInputFingerprint.compute(in: directoryURL), before)
        }
    }

    func testFingerprintIgnoresMergedConfigChanges() throws {
        try TestSupport.withTemporaryDirectory(prefix: "config-input-fingerprint") { directoryURL in
            try TestSupport.write("port: 8317\n", to: directoryURL.appendingPathComponent("config.yaml"))
            let mergedConfigURL = directoryURL.appendingPathComponent("merged-config.yaml")
            let before = ConfigInputFingerprint.compute(in: directoryURL)

            try TestSupport.write("generated: one\n", to: mergedConfigURL)
            let afterWrite = ConfigInputFingerprint.compute(in: directoryURL)
            try TestSupport.write("generated: two\n", to: mergedConfigURL)

            XCTAssertEqual(afterWrite, before)
            XCTAssertEqual(ConfigInputFingerprint.compute(in: directoryURL), before)
        }
    }

    func testFingerprintChangesWhenManagedCredentialChanges() throws {
        try TestSupport.withTemporaryDirectory(prefix: "config-input-fingerprint") { directoryURL in
            let credentialURL = directoryURL.appendingPathComponent("openai-compat-nvidia-a.json")
            try TestSupport.write(#"{"type":"openai-compat","provider":"nvidia","api_key":"nvapi-1"}"#, to: credentialURL)
            let before = ConfigInputFingerprint.compute(in: directoryURL)

            try TestSupport.write(#"{"type":"openai-compat","provider":"nvidia","api_key":"nvapi-1","disabled":true}"#, to: credentialURL)

            XCTAssertNotEqual(ConfigInputFingerprint.compute(in: directoryURL), before)
        }
    }
}
