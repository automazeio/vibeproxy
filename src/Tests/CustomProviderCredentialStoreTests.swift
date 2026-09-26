import Foundation
import XCTest
@testable import CLIProxyMenuBar

final class CustomProviderCredentialStoreTests: XCTestCase {
    func testSaveAndLoadCredential() throws {
        try TestSupport.withTemporaryDirectory(prefix: "custom-provider-credentials") { directoryURL in
            let store = CustomProviderCredentialStore(directoryURL: directoryURL)
            let result = try store.save(
                providerID: "nvidia",
                apiKey: "nvapi-1234567890abcdef",
                label: "primary-nvidia-key"
            )
            guard case .created(let createdRecord) = result else {
                return XCTFail("The first save should create a credential file")
            }

            let loaded = store.loadAll()
            XCTAssertTrue(loaded.issues.isEmpty)
            let record = try XCTUnwrap(loaded.records.first)
            XCTAssertEqual(loaded.records.count, 1)
            XCTAssertEqual(record.providerID, "nvidia")
            XCTAssertEqual(record.apiKey, "nvapi-1234567890abcdef")
            XCTAssertEqual(record.label, "primary-nvidia-key")
            XCTAssertFalse(record.isDisabled)
            XCTAssertEqual(record.filePath.standardizedFileURL, createdRecord.filePath.standardizedFileURL)
            XCTAssertEqual(try TestSupport.filePermissions(at: record.filePath), 0o600)
        }
    }

    func testConcurrentSavesDeduplicateCredential() throws {
        try TestSupport.withTemporaryDirectory(prefix: "custom-provider-credentials") { directoryURL in
            let store = CustomProviderCredentialStore(directoryURL: directoryURL)
            let group = DispatchGroup()
            let queue = DispatchQueue.global(qos: .userInitiated)

            for _ in 0..<25 {
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

            let loaded = store.loadAll()
            XCTAssertTrue(loaded.issues.isEmpty)
            XCTAssertEqual(loaded.records.count, 1)
            XCTAssertFalse(try XCTUnwrap(loaded.records.first).isDisabled)
        }
    }

    func testSavingDisabledCredentialReenablesIt() throws {
        try TestSupport.withTemporaryDirectory(prefix: "custom-provider-credentials") { directoryURL in
            let store = CustomProviderCredentialStore(directoryURL: directoryURL)
            _ = try store.save(providerID: "nvidia", apiKey: "nvapi-abcdef1234567890", label: "primary")
            _ = try store.setDisabled(providerID: "nvidia", apiKey: "nvapi-abcdef1234567890", isDisabled: true)

            let result = try store.save(
                providerID: "nvidia",
                apiKey: "nvapi-abcdef1234567890",
                label: "primary"
            )
            guard case .reenabled = result else {
                return XCTFail("Saving a disabled credential should re-enable it")
            }

            let loaded = store.loadAll()
            XCTAssertEqual(loaded.records.count, 1)
            XCTAssertFalse(try XCTUnwrap(loaded.records.first).isDisabled)
        }
    }

    func testMalformedCredentialIsReportedWithoutHidingValidCredentials() throws {
        try TestSupport.withTemporaryDirectory(prefix: "custom-provider-credentials") { directoryURL in
            let store = CustomProviderCredentialStore(directoryURL: directoryURL)
            try Data("{not-json".utf8).write(
                to: directoryURL.appendingPathComponent("openai-compat-bad.json"),
                options: .atomic
            )
            _ = try store.save(providerID: "nvidia", apiKey: "nvapi-good1234567890", label: "good-key")

            let loaded = store.loadAll()
            XCTAssertEqual(loaded.records.count, 1)
            XCTAssertEqual(loaded.issues.count, 1)
            XCTAssertTrue(try XCTUnwrap(loaded.issues.first).message.contains("invalid JSON"))
        }
    }

    func testDeleteRemovesCredential() throws {
        try TestSupport.withTemporaryDirectory(prefix: "custom-provider-credentials") { directoryURL in
            let store = CustomProviderCredentialStore(directoryURL: directoryURL)
            let result = try store.save(
                providerID: "nvidia",
                apiKey: "nvapi-delete1234567890",
                label: "delete-me"
            )
            guard case .created(let record) = result else {
                return XCTFail("The delete fixture should create a credential file")
            }

            let deletedCount = try store.delete(
                providerID: "nvidia",
                apiKey: "nvapi-delete1234567890"
            )

            XCTAssertEqual(deletedCount, 1)
            XCTAssertFalse(FileManager.default.fileExists(atPath: record.filePath.path))
            XCTAssertTrue(store.loadAll().records.isEmpty)
        }
    }
}
