import XCTest
@testable import CLIProxyMenuBar

final class ProviderWiringTests: XCTestCase {
    func testConnectionActionMatchesExistingProviderFlows() {
        XCTAssertEqual(ServiceType.claude.connectionAction, .authCommand(.claudeLogin))
        XCTAssertEqual(ServiceType.codex.connectionAction, .authCommand(.codexLogin))
        XCTAssertEqual(ServiceType.copilot.connectionAction, .authCommand(.copilotLogin))
        XCTAssertEqual(ServiceType.gemini.connectionAction, .authCommand(.geminiLogin))
        XCTAssertEqual(ServiceType.kimi.connectionAction, .authCommand(.kimiLogin))
        XCTAssertEqual(ServiceType.qwen.connectionAction, .promptForQwenEmail)
        XCTAssertEqual(ServiceType.antigravity.connectionAction, .authCommand(.antigravityLogin))
        XCTAssertEqual(ServiceType.xai.connectionAction, .authCommand(.xaiLogin))
        XCTAssertEqual(ServiceType.zai.connectionAction, .promptForZAIAPIKey)
    }

    func testKimiProviderCatalogRegistrationMatchesRuntimeProviderKey() {
        XCTAssertEqual(ProviderCatalog.oauthProviderKeys["kimi"], "kimi")
        XCTAssertTrue(ProviderCatalog.reservedCustomProviderKeys.contains("kimi"))
    }

    func testXAIProviderCatalogRegistrationPreservesExistingCustomProviders() {
        XCTAssertEqual(ProviderCatalog.oauthProviderKeys["xai"], "xai")
        XCTAssertFalse(ProviderCatalog.reservedCustomProviderKeys.contains("xai"))
    }
}
