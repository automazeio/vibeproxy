import XCTest
@testable import CLIProxyMenuBar

final class BackendCapabilitiesTests: XCTestCase {
    /// Trimmed from the real `cli-proxy-api-plus --help` output of the Plus-era
    /// backend (6.9.5-0-plus) that shipped before the switch to stock builds.
    private static let plusHelpFixture = """
        CLIProxyAPI Version: 6.9.5-0-plus, Commit: f8d1bc06, BuiltAt: 2026-03-29T04:41:24Z
        Usage of /Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus
          -antigravity-login
            Login to Antigravity using OAuth
          -claude-login
            Login to Claude using OAuth
          -config string
            Configure File Path
          -github-copilot-login
            Login to GitHub Copilot using device flow
          -kimi-login
            Login to Kimi using OAuth
          -login
            Login Google Account
          -oauth-callback-port int
            Override OAuth callback port (defaults to provider-specific port)
          -project_id string
            Project ID (Gemini only, not required)
          -qwen-login
            Login to Qwen using OAuth
        """

    /// Trimmed from the real stock CLIProxyAPI 7.3.18 --help output. The Gemini,
    /// Qwen, and GitHub Copilot login flags are gone (#351, #457, #396).
    private static let stockHelpFixture = """
        CLIProxyAPI Version: 7.3.18, Commit: ed980be3, BuiltAt: 2026-09-26T05:59:49Z
        Usage of /tmp/cliproxy-stock/cli-proxy-api
          -antigravity-login
            Login to Antigravity using OAuth
          -claude-login
            Login to Claude using OAuth
          -codex-login
            Login to Codex using OAuth
          -config string
            Configure File Path
          -kimi-login
            Login to Kimi (.com) using OAuth
          -no-browser
            Don't open browser automatically for OAuth
        """

    func testParsesFlagsFromPlusHelpOutput() {
        let capabilities = BackendCapabilities(helpOutput: Self.plusHelpFixture)

        XCTAssertEqual(capabilities.definedFlags, [
            "antigravity-login", "claude-login", "config", "github-copilot-login",
            "kimi-login", "login", "oauth-callback-port", "project_id", "qwen-login"
        ])
    }

    func testStockBackendOmitsPlusOnlyLoginFlags() {
        let capabilities = BackendCapabilities(helpOutput: Self.stockHelpFixture)

        // Still defined by stock builds:
        XCTAssertTrue(capabilities.defines(flag: "claude-login"))
        XCTAssertTrue(capabilities.defines(flag: "codex-login"))
        XCTAssertTrue(capabilities.defines(flag: "kimi-login"))
        // Removed from stock CLIProxyAPI - the regression behind #351, #457, #396:
        XCTAssertFalse(capabilities.defines(flag: "github-copilot-login"))
        XCTAssertFalse(capabilities.defines(flag: "login"))
        XCTAssertFalse(capabilities.defines(flag: "qwen-login"))
    }

    func testIgnoresProseLinesInHelpOutput() {
        let capabilities = BackendCapabilities(
            helpOutput: "CLIProxyAPI Version: 7.3.18\nUsage of /tmp/cli-proxy-api"
        )

        XCTAssertTrue(capabilities.definedFlags.isEmpty)
    }

    func testEmptyHelpYieldsNoFlags() {
        XCTAssertTrue(BackendCapabilities(helpOutput: "").definedFlags.isEmpty)
    }
}

final class AuthCommandFlagMappingTests: XCTestCase {
    func testRequiredBackendFlags() {
        XCTAssertEqual(AuthCommand.claudeLogin.requiredBackendFlag, "claude-login")
        XCTAssertEqual(AuthCommand.codexLogin.requiredBackendFlag, "codex-login")
        XCTAssertEqual(AuthCommand.copilotLogin.requiredBackendFlag, "github-copilot-login")
        XCTAssertEqual(AuthCommand.geminiLogin.requiredBackendFlag, "login")
        XCTAssertEqual(AuthCommand.kimiLogin.requiredBackendFlag, "kimi-login")
        XCTAssertEqual(AuthCommand.qwenLogin(email: "user@example.com").requiredBackendFlag, "qwen-login")
        XCTAssertEqual(AuthCommand.antigravityLogin.requiredBackendFlag, "antigravity-login")
    }

    func testDisplayNames() {
        XCTAssertEqual(AuthCommand.copilotLogin.displayName, "GitHub Copilot")
        XCTAssertEqual(AuthCommand.qwenLogin(email: "user@example.com").displayName, "Qwen")
    }
}
