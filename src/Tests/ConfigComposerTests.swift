import XCTest
@testable import CLIProxyMenuBar

final class ConfigComposerTests: XCTestCase {
    func testPreservesRuntimeEditedTopLevelAPIKeysWhenBaseDoesNotDefineThem() {
        let root: [String: Any] = ["port": 8318]
        let runtimeRoot: [String: Any] = [
            "api-keys": ["local-key"],
            "port": 9000
        ]

        let result = ConfigComposer.preservingRuntimeEditableTopLevelKeys(
            in: root,
            from: runtimeRoot
        )

        XCTAssertEqual(result["api-keys"] as? [String], ["local-key"])
        XCTAssertEqual(result["port"] as? Int, 8318)
    }

    func testDoesNotOverwriteExplicitTopLevelAPIKeys() {
        let root: [String: Any] = ["api-keys": ["configured-key"]]
        let runtimeRoot: [String: Any] = ["api-keys": ["runtime-key"]]

        let result = ConfigComposer.preservingRuntimeEditableTopLevelKeys(
            in: root,
            from: runtimeRoot
        )

        XCTAssertEqual(result["api-keys"] as? [String], ["configured-key"])
    }

    func testAdditiveConfigPreservesDefaultsAndAddsUserProvider() {
        let bundledRoot: [String: Any] = [
            "port": 8317,
            "routing": ["strategy": "round-robin"],
            "openai-compatibility": [[
                "name": "existing",
                "base-url": "https://existing.example.com/v1",
                "models": [["name": "existing/model", "alias": "existing-model"]]
            ]]
        ]
        let userRoot: [String: Any] = [
            "request-timeout": "30m",
            "openai-compatibility": [[
                "name": "nvidia",
                "display-name": "NVIDIA",
                "base-url": "https://integrate.api.nvidia.com/v1",
                "models": [["name": "z-ai/glm5", "alias": "glm5"]]
            ]]
        ]

        let merged = ConfigComposer.composeAdditiveBaseConfig(bundledRoot: bundledRoot, userRoot: userRoot)

        XCTAssertEqual(merged["port"] as? Int, 8317)
        XCTAssertEqual(merged["request-timeout"] as? String, "30m")
        XCTAssertEqual(dictionary(merged["routing"])["strategy"] as? String, "round-robin")
        XCTAssertEqual(providerEntries(in: merged).count, 2)
        XCTAssertEqual(provider(named: "existing", in: merged)?["base-url"] as? String, "https://existing.example.com/v1")
        XCTAssertEqual(provider(named: "nvidia", in: merged)?["display-name"] as? String, "NVIDIA")
    }

    func testAdditiveConfigMergesProviderOverridesByName() {
        let bundledRoot: [String: Any] = [
            "openai-compatibility": [[
                "name": "nvidia",
                "base-url": "https://old.example.com/v1",
                "help-text": "Bundled help",
                "models": [["name": "old/model", "alias": "old-model"]]
            ]]
        ]
        let userRoot: [String: Any] = [
            "openai-compatibility": [[
                "name": "nvidia",
                "base-url": "https://integrate.api.nvidia.com/v1",
                "display-name": "NVIDIA"
            ]]
        ]

        let merged = ConfigComposer.composeAdditiveBaseConfig(bundledRoot: bundledRoot, userRoot: userRoot)
        let nvidia = provider(named: "nvidia", in: merged)

        XCTAssertEqual(nvidia?["base-url"] as? String, "https://integrate.api.nvidia.com/v1")
        XCTAssertEqual(nvidia?["display-name"] as? String, "NVIDIA")
        XCTAssertEqual(nvidia?["help-text"] as? String, "Bundled help")
        XCTAssertEqual(providerEntries(in: merged).count, 1)
    }

    func testAdditiveConfigPreservesProviderOrderAndAppendsNewProviders() {
        let bundledRoot: [String: Any] = [
            "openai-compatibility": [
                ["name": "alpha", "base-url": "https://alpha.example.com/v1"],
                ["name": "beta", "base-url": "https://beta.example.com/v1"]
            ]
        ]
        let userRoot: [String: Any] = [
            "openai-compatibility": [
                ["name": "beta", "display-name": "Beta Override"],
                ["name": "gamma", "base-url": "https://gamma.example.com/v1"]
            ]
        ]

        let merged = ConfigComposer.composeAdditiveBaseConfig(bundledRoot: bundledRoot, userRoot: userRoot)

        XCTAssertEqual(providerEntries(in: merged).compactMap { $0["name"] as? String }, ["alpha", "beta", "gamma"])
        XCTAssertEqual(provider(named: "beta", in: merged)?["display-name"] as? String, "Beta Override")
    }

    func testAdditiveConfigIgnoresEmptyProviderOverlay() {
        let bundledRoot: [String: Any] = [
            "openai-compatibility": [["name": "existing", "base-url": "https://existing.example.com/v1"]]
        ]
        let userRoot: [String: Any] = ["openai-compatibility": []]

        let merged = ConfigComposer.composeAdditiveBaseConfig(bundledRoot: bundledRoot, userRoot: userRoot)

        XCTAssertEqual(providerEntries(in: merged).compactMap { $0["name"] as? String }, ["existing"])
    }

    func testCustomProviderParsingExcludesReservedProvidersAndPreservesMetadata() {
        let root: [String: Any] = [
            "openai-compatibility": [
                [
                    "name": "zai",
                    "display-name": "Managed Z.AI",
                    "base-url": "https://api.z.ai/api/coding/paas/v4"
                ],
                [
                    "name": "nvidia",
                    "display-name": "NVIDIA",
                    "help-text": "OpenAI-compatible NVIDIA endpoint",
                    "icon-system": "bolt.fill",
                    "base-url": "https://integrate.api.nvidia.com/v1",
                    "api-key-entries": [["api-key": "inline-a"], ["api-key": "inline-a"]],
                    "models": [["name": "z-ai/glm5", "alias": "glm5"]]
                ]
            ]
        ]

        let providers = ConfigComposer.parseCustomProviders(
            from: root,
            reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys
        )
        let provider = providers.first

        XCTAssertEqual(providers.count, 1)
        XCTAssertEqual(provider?.id, "nvidia")
        XCTAssertEqual(provider?.title, "NVIDIA")
        XCTAssertEqual(provider?.helpText, "OpenAI-compatible NVIDIA endpoint")
        XCTAssertEqual(provider?.iconSystemName, "bolt.fill")
        XCTAssertEqual(provider?.modelAliases, ["glm5"])
        XCTAssertEqual(provider?.inlineKeyCount, 1)
    }

    func testRuntimeConfigPreservesUserOAuthExclusions() {
        let baseRoot: [String: Any] = [
            "oauth-excluded-models": [
                "claude": ["claude-sonnet-4"],
                "custom-oauth": ["x"]
            ]
        ]

        let runtime = composeRuntimeConfig(
            baseRoot: baseRoot,
            disabledOAuthProviderKeys: ["gemini-cli"]
        )
        let exclusions = dictionary(runtime["oauth-excluded-models"])

        XCTAssertEqual(exclusions["claude"] as? [String], ["claude-sonnet-4"])
        XCTAssertEqual(exclusions["custom-oauth"] as? [String], ["x"])
        XCTAssertEqual(exclusions["gemini-cli"] as? [String], ["*"])
    }

    func testRuntimeConfigStripsMetadataDeduplicatesKeysAndInjectsZAI() {
        let baseRoot: [String: Any] = [
            "openai-compatibility": [[
                "name": "nvidia",
                "display-name": "NVIDIA",
                "help-text": "UI metadata",
                "icon-system": "bolt.fill",
                "base-url": "https://integrate.api.nvidia.com/v1",
                "api-key-entries": [["api-key": "inline-a"], ["api-key": "inline-b"]],
                "models": [["name": "z-ai/glm5", "alias": "glm5"]]
            ]]
        ]

        let runtime = ConfigComposer.composeRuntimeConfig(
            baseRoot: baseRoot,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: [],
            disabledOAuthProviderKeys: [],
            zaiAPIKeys: ["zai-key-1"],
            customProviderAuthRecords: [
                ConfigProviderAuthRecord(providerID: "nvidia", apiKey: "inline-a", isDisabled: false),
                ConfigProviderAuthRecord(providerID: "nvidia", apiKey: "auth-c", isDisabled: false),
                ConfigProviderAuthRecord(providerID: "nvidia", apiKey: "auth-d", isDisabled: true)
            ],
            includeManagedZAIProvider: true
        )
        let nvidia = provider(named: "nvidia", in: runtime)

        XCTAssertNil(nvidia?["display-name"])
        XCTAssertNil(nvidia?["help-text"])
        XCTAssertNil(nvidia?["icon-system"])
        XCTAssertEqual(apiKeys(in: nvidia ?? [:]), ["inline-a", "inline-b", "auth-c"])
        XCTAssertEqual(apiKeys(in: provider(named: "zai", in: runtime) ?? [:]), ["zai-key-1"])
    }

    func testRuntimeConfigPreservesUserZAIModelsAndMergesKeys() {
        let baseRoot: [String: Any] = [
            "openai-compatibility": [[
                "name": "zai",
                "display-name": "Z.AI",
                "base-url": "https://api.z.ai/api/coding/paas/v4",
                "api-key-entries": [["api-key": "inline-zai"]],
                "models": [
                    ["name": "glm-4.7", "alias": "glm-4.7"],
                    ["name": "glm-5", "alias": "glm-5"],
                    ["name": "glm-5-turbo", "alias": "glm-5-turbo"]
                ]
            ]]
        ]

        let runtime = ConfigComposer.composeRuntimeConfig(
            baseRoot: baseRoot,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: [],
            disabledOAuthProviderKeys: [],
            zaiAPIKeys: ["managed-zai", "inline-zai"],
            customProviderAuthRecords: [],
            includeManagedZAIProvider: true
        )
        let zai = provider(named: "zai", in: runtime) ?? [:]

        XCTAssertEqual(apiKeys(in: zai), ["inline-zai", "managed-zai"])
        XCTAssertEqual(modelAliases(in: zai), ["glm-4.7", "glm-5", "glm-5-turbo"])
        XCTAssertNil(zai["display-name"])
    }

    func testRuntimeConfigOmitsDisabledCustomProvider() {
        let baseRoot: [String: Any] = [
            "openai-compatibility": [[
                "name": "nvidia",
                "base-url": "https://integrate.api.nvidia.com/v1",
                "models": [["name": "z-ai/glm5", "alias": "glm5"]]
            ]]
        ]

        let runtime = ConfigComposer.composeRuntimeConfig(
            baseRoot: baseRoot,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: ["nvidia"],
            disabledOAuthProviderKeys: [],
            zaiAPIKeys: [],
            customProviderAuthRecords: [
                ConfigProviderAuthRecord(providerID: "nvidia", apiKey: "auth-a", isDisabled: false)
            ],
            includeManagedZAIProvider: false
        )

        XCTAssertNil(provider(named: "nvidia", in: runtime))
    }

    func testOAuthWildcardExclusionDetection() {
        let root: [String: Any] = [
            "oauth-excluded-models": [
                "claude": ["*"],
                "gemini-cli": ["gemini-2.5-pro"]
            ]
        ]

        XCTAssertTrue(ConfigComposer.isOAuthProviderWildcardExcluded("claude", in: root))
        XCTAssertFalse(ConfigComposer.isOAuthProviderWildcardExcluded("gemini-cli", in: root))
    }

    func testCustomProviderValidationRejectsBlankBaseURL() {
        let root: [String: Any] = [
            "openai-compatibility": [
                ["name": "nvidia", "base-url": "   "],
                ["name": "zai", "base-url": ""]
            ]
        ]

        XCTAssertEqual(
            ConfigComposer.validateCustomProviders(
                in: root,
                reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys
            ),
            ["Custom provider 'nvidia' must define a non-empty base-url."]
        )
    }

    func testCustomProviderValidationRejectsMalformedShapes() {
        let malformedRoot: [String: Any] = ["openai-compatibility": ["not-a-provider-mapping"]]
        let scalarRoot: [String: Any] = ["openai-compatibility": "not-an-array"]

        XCTAssertEqual(
            ConfigComposer.validateCustomProviders(
                in: malformedRoot,
                reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys
            ),
            ["openai-compatibility[0] must be a mapping."]
        )
        XCTAssertEqual(
            ConfigComposer.validateCustomProviders(
                in: scalarRoot,
                reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys
            ),
            ["openai-compatibility must be an array of provider mappings."]
        )
    }

    func testCustomProviderValidationRejectsNoncanonicalAndReservedIDs() {
        let root: [String: Any] = [
            "openai-compatibility": [
                ["name": " zai ", "base-url": "https://api.z.ai/api/coding/paas/v4"],
                ["name": "gemini-cli", "base-url": "https://example.com/v1"]
            ]
        ]

        XCTAssertEqual(
            ConfigComposer.validateCustomProviders(
                in: root,
                reservedProviderIDs: ProviderCatalog.reservedCustomProviderKeys
            ),
            [
                "Provider name ' zai ' must not include leading or trailing whitespace.",
                "Provider 'gemini-cli' is reserved and cannot be declared under openai-compatibility."
            ]
        )
    }

    private func composeRuntimeConfig(
        baseRoot: [String: Any],
        disabledOAuthProviderKeys: [String] = []
    ) -> [String: Any] {
        ConfigComposer.composeRuntimeConfig(
            baseRoot: baseRoot,
            reservedCustomProviderKeys: ProviderCatalog.reservedCustomProviderKeys,
            disabledCustomProviderIDs: [],
            disabledOAuthProviderKeys: disabledOAuthProviderKeys,
            zaiAPIKeys: [],
            customProviderAuthRecords: [],
            includeManagedZAIProvider: false
        )
    }

    private func providerEntries(in root: [String: Any]) -> [[String: Any]] {
        ConfigComposer.stringKeyedDictionaryArray(root["openai-compatibility"])
    }

    private func provider(named name: String, in root: [String: Any]) -> [String: Any]? {
        providerEntries(in: root).first { $0["name"] as? String == name }
    }

    private func dictionary(_ value: Any?) -> [String: Any] {
        guard let value else { return [:] }
        return ConfigComposer.stringKeyedDictionary(value) ?? [:]
    }

    private func apiKeys(in provider: [String: Any]) -> [String] {
        ConfigComposer.stringKeyedDictionaryArray(provider["api-key-entries"])
            .compactMap { $0["api-key"] as? String }
    }

    private func modelAliases(in provider: [String: Any]) -> [String] {
        ConfigComposer.stringKeyedDictionaryArray(provider["models"])
            .compactMap { ($0["alias"] as? String) ?? ($0["name"] as? String) }
    }
}
