@testable import CLIProxyMenuBar
import XCTest

final class ServerManagerAuthCommandTests: XCTestCase {
    func testGeminiLoginUsesGoogleOneProjectDiscovery() {
        let arguments = ServerManager.authArguments(for: .geminiLogin, configPath: "/tmp/config.yaml")

        XCTAssertEqual(
            arguments,
            ["--config", "/tmp/config.yaml", "--project_id", "GOOGLE_ONE", "-login"]
        )
    }

    func testCodexLoginArgumentsRemainUnchanged() {
        let arguments = ServerManager.authArguments(for: .codexLogin, configPath: "/tmp/config.yaml")

        XCTAssertEqual(arguments, ["--config", "/tmp/config.yaml", "-codex-login"])
    }
}
