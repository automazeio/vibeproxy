import XCTest
@testable import CLIProxyMenuBar

final class ClaudeSetupTokenStoreTests: XCTestCase {
    func testSavesClaudeSetupTokenCredentialWithExpectedFlagsAndPermissions() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let store = ClaudeSetupTokenStore(authDirectory: directory)
            let saved = try store.save(label: "Work-account", setupToken: "sk-ant-oat01-valid-token")

            XCTAssertEqual(saved.lastPathComponent, "claude-Work-account.json")
            XCTAssertEqual(try TestSupport.filePermissions(at: directory), 0o700)
            XCTAssertEqual(try TestSupport.filePermissions(at: saved), 0o600)

            let data = try Data(contentsOf: saved)
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            XCTAssertEqual(json["type"] as? String, "claude")
            XCTAssertEqual(json["access_token"] as? String, "sk-ant-oat01-valid-token")
            XCTAssertEqual(json["refresh_token"] as? String, "")
            XCTAssertEqual(json["is_setup_token"] as? Bool, true)
            XCTAssertEqual(json["skip_account_profile"] as? Bool, true)
            XCTAssertEqual(json["label"] as? String, "Work-account")
            XCTAssertNil(json["login"])
            XCTAssertNil(json["email"])
            XCTAssertNil(json["expired"])
            XCTAssertEqual(json["disabled"] as? Bool, false)
        }
    }

    func testRejectsEmptyLabelAndAnthropicAPIKey() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let store = ClaudeSetupTokenStore(authDirectory: directory)

            XCTAssertThrowsError(try store.save(label: "   ", setupToken: "sk-ant-oat01-valid-token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .emptyLabel)
            }
            XCTAssertThrowsError(try store.save(label: "API key", setupToken: "sk-ant-api03-not-a-setup-token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .invalidToken)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
        }
    }

    func testRejectsInvalidSetupTokenAndLeavesDirectoryEmpty() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let store = ClaudeSetupTokenStore(authDirectory: directory)
            XCTAssertThrowsError(try store.save(label: "Personal-account", setupToken: "not-a-token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .invalidToken)
            }
            XCTAssertThrowsError(try store.save(label: "Personal-account", setupToken: "sk-ant-oat01-short")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .invalidToken)
            }
            XCTAssertThrowsError(try store.save(label: "Personal-account", setupToken: "sk-ant-oat01-valid token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .invalidToken)
            }
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
        }
    }

    func testRejectsDuplicateSetupTokenWithoutCreatingAnotherFile() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let store = ClaudeSetupTokenStore(authDirectory: directory)
            _ = try store.save(label: "Personal-account", setupToken: "sk-ant-oat01-same-token")

            XCTAssertThrowsError(try store.save(label: "Other", setupToken: "sk-ant-oat01-same-token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .duplicateToken)
            }
            let files = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasSuffix(".json") }
            XCTAssertEqual(files, ["claude-Personal-account.json"])
        }
    }

    func testRejectsDuplicateSetupTokenFromArbitraryClaudeJSONFilename() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let existing = directory.appendingPathComponent("manual-import.json")
            try TestSupport.write("""
            {
              "type": "claude",
              "access_token": "sk-ant-oat01-same-token"
            }
            """, to: existing)

            let store = ClaudeSetupTokenStore(authDirectory: directory)
            XCTAssertThrowsError(try store.save(label: "Other", setupToken: "sk-ant-oat01-same-token")) { error in
                XCTAssertEqual(error as? ClaudeSetupTokenStoreError, .duplicateToken)
            }
            XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("claude-Other.json").path))
        }
    }

    func testNameCollisionCreatesNewFileWithoutOverwritingExistingCredential() throws {
        try TestSupport.withTemporaryDirectory(prefix: "claude-setup-token") { directory in
            let store = ClaudeSetupTokenStore(authDirectory: directory)
            let first = try store.save(label: "Personal-account", setupToken: "sk-ant-oat01-first-token")
            let second = try store.save(label: "Personal-account", setupToken: "sk-ant-oat01-second-token")

            XCTAssertEqual(first.lastPathComponent, "claude-Personal-account.json")
            XCTAssertEqual(second.lastPathComponent, "claude-Personal-account-2.json")
            let firstJSON = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: first)) as? [String: Any])
            XCTAssertEqual(firstJSON["access_token"] as? String, "sk-ant-oat01-first-token")
        }
    }

    func testAuthManagerDisplaysSetupTokenLabel() throws {
        let account = AuthAccount(
            id: "claude-Personal-account.json",
            email: nil,
            login: nil,
            label: "Personal-account",
            type: .claude,
            expired: nil,
            filePath: URL(fileURLWithPath: "/tmp/claude-Personal-account.json"),
            isDisabled: false
        )
        XCTAssertEqual(account.displayName, "Personal-account")
    }
    func testExistingEmailAndLoginDisplayNamesKeepTheirPriority() {
        let cases: [(String?, String?, String?, String)] = [
            ("account@example.com", "existing-login", "Local label", "account@example.com"),
            (nil, "existing-login", "Local label", "existing-login"),
            (nil, nil, "Local label", "Local label"),
            (nil, nil, nil, "credential.json")
        ]
        for (email, login, label, expected) in cases {
            let account = AuthAccount(
                id: "credential.json", email: email, login: login, label: label,
                type: .claude, expired: nil,
                filePath: URL(fileURLWithPath: "/tmp/credential.json"), isDisabled: false
            )
            XCTAssertEqual(account.displayName, expected)
        }
    }

}
