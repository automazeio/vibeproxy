import Foundation
import XCTest
@testable import CLIProxyMenuBar

final class AuthManagerTests: XCTestCase {
    func testAccountEqualityIncludesAuthState() {
        let fileURL = URL(fileURLWithPath: "/tmp/codex-test.json")
        let enabled = fixtureAccount(at: fileURL, disabled: false)
        let disabled = fixtureAccount(at: fileURL, disabled: true)

        XCTAssertNotEqual(enabled, disabled)
    }

    func testAccountCanBeDisabledAndReenabled() throws {
        try TestSupport.withTemporaryDirectory(prefix: "auth-manager") { directoryURL in
            let accountURL = directoryURL.appendingPathComponent("codex-test.json")
            let otherURL = directoryURL.appendingPathComponent("codex-other.json")
            try writeAccount(to: accountURL, disabled: false)
            try writeAccount(to: otherURL, disabled: false)

            let account = fixtureAccount(at: accountURL, disabled: false)
            let other = fixtureAccount(at: otherURL, disabled: false)
            let manager = AuthManager(authDirectory: directoryURL)
            manager.serviceAccounts[.codex] = ServiceAccounts(type: .codex, accounts: [account, other])

            XCTAssertTrue(manager.toggleAccountDisabled(account))
            XCTAssertTrue(try disabledValue(at: accountURL))

            let disabledAccount = fixtureAccount(at: accountURL, disabled: true)
            manager.serviceAccounts[.codex] = ServiceAccounts(type: .codex, accounts: [disabledAccount, other])
            XCTAssertTrue(manager.toggleAccountDisabled(disabledAccount))
            XCTAssertFalse(try disabledValue(at: accountURL))
        }
    }

    func testLastEnabledAccountCannotBeDisabled() throws {
        try TestSupport.withTemporaryDirectory(prefix: "auth-manager") { directoryURL in
            let accountURL = directoryURL.appendingPathComponent("codex-test.json")
            try writeAccount(to: accountURL, disabled: false)
            let account = fixtureAccount(at: accountURL, disabled: false)
            let manager = AuthManager(authDirectory: directoryURL)
            manager.serviceAccounts[.codex] = ServiceAccounts(type: .codex, accounts: [account])

            XCTAssertFalse(manager.toggleAccountDisabled(account))
            XCTAssertFalse(try disabledValue(at: accountURL))
        }
    }

    private func fixtureAccount(at url: URL, disabled: Bool) -> AuthAccount {
        AuthAccount(
            id: url.lastPathComponent,
            email: "test@example.com",
            login: nil,
            type: .codex,
            expired: nil,
            filePath: url,
            isDisabled: disabled
        )
    }

    private func writeAccount(to url: URL, disabled: Bool) throws {
        let data = try JSONSerialization.data(withJSONObject: [
            "type": "codex",
            "email": "test@example.com",
            "disabled": disabled
        ])
        try data.write(to: url, options: .atomic)
    }

    private func disabledValue(at url: URL) throws -> Bool {
        let data = try Data(contentsOf: url)
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return object["disabled"] as? Bool ?? false
    }
}
