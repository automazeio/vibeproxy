import XCTest
@testable import CLIProxyMenuBar

final class GrokProviderConfigurationTests: XCTestCase {
    private let base: [String: Any] = [
        "port": 8318,
        "oauth-excluded-models": ["xai": ["grok-hidden"], "claude": ["claude-hidden"]],
        "openai-compatibility": [[
            "name": "xai", "base-url": "https://api.x.ai/v1",
            "api-key-entries": [["api-key": "synthetic-inline-key"]],
            "models": [["name": "grok-test", "alias": "custom-grok"]]
        ]]
    ]

    func testEveryCombinationOfOAuthAndCustomTogglePreservesOtherConfiguration() {
        XCTAssertTrue(ConfigComposer.validateCustomProviders(in: base, reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys).isEmpty)
        for oauthEnabled in [false, true] {
            for customEnabled in [false, true] {
                let result = compose(base, oauthEnabled: oauthEnabled, customEnabled: customEnabled)
                let exclusions = ConfigComposer.stringKeyedDictionary(result["oauth-excluded-models"]!)!
                // A disabled provider's runtime exclusion is '*'. Recomposition
                // from the untouched base restores individual exclusions.
                XCTAssertEqual(ConfigComposer.stringArray(exclusions["xai"]), oauthEnabled ? ["grok-hidden"] : ["*"])
                XCTAssertEqual(ConfigComposer.stringArray(exclusions["claude"]), ["claude-hidden"])
                XCTAssertEqual(result["port"] as? Int, 8318)
                let providers = ConfigComposer.stringKeyedDictionaryArray(result["openai-compatibility"])
                XCTAssertEqual(providers.count, customEnabled ? 1 : 0)
                if let provider = providers.first {
                    XCTAssertEqual(provider["name"] as? String, "xai")
                    XCTAssertEqual(provider["base-url"] as? String, "https://api.x.ai/v1")
                    XCTAssertEqual(ConfigComposer.stringKeyedDictionaryArray(provider["models"]).first?["alias"] as? String, "custom-grok")
                    let keys = ConfigComposer.stringKeyedDictionaryArray(provider["api-key-entries"]).compactMap { $0["api-key"] as? String }
                    XCTAssertEqual(Set(keys), ["synthetic-inline-key", "synthetic-stored-key"])
                }
            }
        }
        let reenabled = compose(base, oauthEnabled: true, customEnabled: true)
        let exclusions = ConfigComposer.stringKeyedDictionary(reenabled["oauth-excluded-models"]!)!
        XCTAssertEqual(ConfigComposer.stringArray(exclusions["xai"]), ["grok-hidden"])
    }

    func testManualWildcardRemainsWhenOAuthIsEnabledInUI() {
        var root = base
        root["oauth-excluded-models"] = ["xai": ["*", "grok-hidden"]]
        let result = compose(root, oauthEnabled: true, customEnabled: true)
        XCTAssertTrue(ConfigComposer.isOAuthProviderWildcardExcluded("xai", in: result))
        XCTAssertEqual(ConfigComposer.parseCustomProviders(from: result, reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys).map(\.id), ["xai"])
        XCTAssertEqual(ProviderCatalog.oauthProviderKeys["xai-oauth"], "xai")
        XCTAssertNil(ProviderCatalog.oauthProviderKeys["xai"])
    }

    private func compose(_ root: [String: Any], oauthEnabled: Bool, customEnabled: Bool) -> [String: Any] {
        ConfigComposer.composeRuntimeConfig(
            baseRoot: root,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: customEnabled ? [] : ["xai"],
            disabledOAuthProviderKeys: oauthEnabled ? [] : ["xai"],
            zaiAPIKeys: [],
            customProviderAuthRecords: [.init(providerID: "xai", apiKey: "synthetic-stored-key", isDisabled: false)],
            includeManagedZAIProvider: false
        )
    }
}
