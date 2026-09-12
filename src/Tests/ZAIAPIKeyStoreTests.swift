import Foundation
import XCTest
@testable import CLIProxyMenuBar

final class ZAIAPIKeyStoreTests: XCTestCase {
    func testSaveAndLoadActiveAPIKey() throws {
        try TestSupport.withTemporaryDirectory(prefix: "zai-api-key-store") { directoryURL in
            let store = ZAIAPIKeyStore(directoryURL: directoryURL)
            let fileURL = try store.save(apiKey: "zai-1234567890abcdef")

            let loaded = store.loadActiveAPIKeys()
            XCTAssertTrue(loaded.issues.isEmpty)
            XCTAssertEqual(loaded.apiKeys, ["zai-1234567890abcdef"])
            XCTAssertEqual(try TestSupport.filePermissions(at: fileURL), 0o600)
        }
    }

    func testDisabledAPIKeyIsExcluded() throws {
        try TestSupport.withTemporaryDirectory(prefix: "zai-api-key-store") { directoryURL in
            let store = ZAIAPIKeyStore(directoryURL: directoryURL)
            let disabledJSON: [String: Any] = [
                "type": "zai",
                "email": "masked@example.com",
                "api_key": "zai-disabled",
                "disabled": true
            ]
            let data = try JSONSerialization.data(withJSONObject: disabledJSON, options: [.prettyPrinted])
            try data.write(to: directoryURL.appendingPathComponent("zai-disabled.json"), options: .atomic)
            _ = try store.save(apiKey: "zai-enabled")

            let loaded = store.loadActiveAPIKeys()
            XCTAssertTrue(loaded.issues.isEmpty)
            XCTAssertEqual(loaded.apiKeys, ["zai-enabled"])
        }
    }

    func testMalformedAPIKeyFileIsReportedWithoutHidingValidKeys() throws {
        try TestSupport.withTemporaryDirectory(prefix: "zai-api-key-store") { directoryURL in
            let store = ZAIAPIKeyStore(directoryURL: directoryURL)
            try Data("{not-json".utf8).write(
                to: directoryURL.appendingPathComponent("zai-bad.json"),
                options: .atomic
            )
            _ = try store.save(apiKey: "zai-good")

            let loaded = store.loadActiveAPIKeys()
            XCTAssertEqual(loaded.apiKeys, ["zai-good"])
            XCTAssertEqual(loaded.issues.count, 1)
            XCTAssertTrue(try XCTUnwrap(loaded.issues.first).message.contains("invalid JSON"))
        }
    }
}
