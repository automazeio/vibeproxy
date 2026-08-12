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

    func testXAIProviderCatalogRegistrationSeparatesOAuthStateFromCustomProviders() {
        XCTAssertEqual(
            ProviderCatalog.oauthProviderKeys[ProviderCatalog.xaiOAuthProviderStateKey],
            "xai"
        )
        XCTAssertFalse(ProviderCatalog.reservedCustomProviderKeys.contains("xai"))
    }

    func testDisablingXAIOAuthDoesNotRemoveCustomXAIProvider() {
        let baseRoot: [String: Any] = [
            "openai-compatibility": [
                [
                    "name": "xai",
                    "base-url": "https://api.x.ai/v1",
                    "api-key-entries": [["api-key": "test-key"]]
                ]
            ]
        ]

        let runtime = ConfigComposer.composeRuntimeConfig(
            baseRoot: baseRoot,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: [],
            disabledOAuthProviderKeys: ["xai"],
            zaiAPIKeys: [],
            customProviderAuthRecords: [],
            includeManagedZAIProvider: false
        )

        let customProviders = ConfigComposer.stringKeyedDictionaryArray(runtime["openai-compatibility"])
        XCTAssertEqual(customProviders.map { $0["name"] as? String }, ["xai"])
        XCTAssertEqual(
            ConfigComposer.stringArray(
                ConfigComposer.stringKeyedDictionary(runtime["oauth-excluded-models"] ?? [:])?["xai"]
            ),
            ["*"]
        )
    }
}
