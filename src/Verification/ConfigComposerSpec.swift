import Foundation

private let reservedProviderIDs = ProviderCatalog.reservedCustomProviderKeys

@main
struct ConfigComposerSpec {
    static func main() {
        let recorder = FailureRecorder()

        run("composeAdditiveBaseConfig preserves bundled defaults and adds user provider", recorder: recorder) {
            let bundledRoot: [String: Any] = [
                "port": 8317,
                "routing": ["strategy": "round-robin"],
                "openai-compatibility": [
                    [
                        "name": "existing",
                        "base-url": "https://existing.example.com/v1",
                        "models": [
                            ["name": "existing/model", "alias": "existing-model"]
                        ]
                    ]
                ]
            ]
            let userRoot: [String: Any] = [
                "request-timeout": "30m",
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "display-name": "NVIDIA",
                        "base-url": "https://integrate.api.nvidia.com/v1",
                        "models": [
                            ["name": "z-ai/glm5", "alias": "glm5"]
                        ]
                    ]
                ]
            ]

            let merged = ConfigComposer.composeAdditiveBaseConfig(
                bundledRoot: bundledRoot,
                userRoot: userRoot
            )

            expectEqual(merged["port"] as? Int, 8317, "bundled port should remain", recorder: recorder)
            expectEqual(merged["request-timeout"] as? String, "30m", "user timeout should overlay", recorder: recorder)
            expectEqual(dictionary(merged["routing"])["strategy"] as? String, "round-robin", "bundled routing should remain", recorder: recorder)
            expectEqual(providerEntries(in: merged).count, 2, "both bundled and user providers should exist", recorder: recorder)
            expectEqual(provider(named: "existing", in: merged)?["base-url"] as? String, "https://existing.example.com/v1", "bundled provider should remain", recorder: recorder)
            expectEqual(provider(named: "nvidia", in: merged)?["display-name"] as? String, "NVIDIA", "user provider metadata should be present", recorder: recorder)
        }

        run("composeAdditiveBaseConfig merges provider overrides by name", recorder: recorder) {
            let bundledRoot: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "base-url": "https://old.example.com/v1",
                        "help-text": "Bundled help",
                        "models": [
                            ["name": "old/model", "alias": "old-model"]
                        ]
                    ]
                ]
            ]
            let userRoot: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "base-url": "https://integrate.api.nvidia.com/v1",
                        "display-name": "NVIDIA"
                    ]
                ]
            ]

            let merged = ConfigComposer.composeAdditiveBaseConfig(
                bundledRoot: bundledRoot,
                userRoot: userRoot
            )
            let nvidia = provider(named: "nvidia", in: merged)

            expectEqual(nvidia?["base-url"] as? String, "https://integrate.api.nvidia.com/v1", "user provider base-url should override", recorder: recorder)
            expectEqual(nvidia?["display-name"] as? String, "NVIDIA", "user display-name should overlay", recorder: recorder)
            expectEqual(nvidia?["help-text"] as? String, "Bundled help", "bundled help-text should remain", recorder: recorder)
            expectEqual(providerEntries(in: merged).count, 1, "provider entries should merge by name", recorder: recorder)
        }

        run("composeAdditiveBaseConfig preserves bundled provider order and appends new overlays", recorder: recorder) {
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

            let merged = ConfigComposer.composeAdditiveBaseConfig(
                bundledRoot: bundledRoot,
                userRoot: userRoot
            )
            let names = providerEntries(in: merged).compactMap { $0["name"] as? String }

            expectEqual(
                names,
                ["alpha", "beta", "gamma"],
                "bundled provider order should remain stable and new overlay providers should append at the end",
                recorder: recorder
            )
            expectEqual(
                provider(named: "beta", in: merged)?["display-name"] as? String,
                "Beta Override",
                "overlay updates should apply in place without reordering bundled providers",
                recorder: recorder
            )
        }

        run("composeAdditiveBaseConfig ignores empty openai-compatibility overlays", recorder: recorder) {
            let bundledRoot: [String: Any] = [
                "openai-compatibility": [
                    ["name": "existing", "base-url": "https://existing.example.com/v1"]
                ]
            ]
            let userRoot: [String: Any] = [
                "openai-compatibility": []
            ]

            let merged = ConfigComposer.composeAdditiveBaseConfig(
                bundledRoot: bundledRoot,
                userRoot: userRoot
            )

            expectEqual(
                providerEntries(in: merged).compactMap { $0["name"] as? String },
                ["existing"],
                "an empty openai-compatibility overlay should be treated as no additive override",
                recorder: recorder
            )
        }

        run("parseCustomProviders ignores reserved providers and keeps UI metadata", recorder: recorder) {
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
                        "api-key-entries": [
                            ["api-key": "inline-a"],
                            ["api-key": "inline-a"]
                        ],
                        "models": [
                            ["name": "z-ai/glm5", "alias": "glm5"]
                        ]
                    ]
                ]
            ]

            let providers = ConfigComposer.parseCustomProviders(
                from: root,
                reservedProviderIDs: reservedProviderIDs
            )

            expectEqual(providers.count, 1, "reserved providers should be excluded from custom provider list", recorder: recorder)
            expectEqual(providers.first?.id, "nvidia", "nvidia should be exposed as custom provider", recorder: recorder)
            expectEqual(providers.first?.title, "NVIDIA", "display-name should drive provider title", recorder: recorder)
            expectEqual(providers.first?.helpText, "OpenAI-compatible NVIDIA endpoint", "help text should be preserved for UI", recorder: recorder)
            expectEqual(providers.first?.iconSystemName, "bolt.fill", "icon metadata should be preserved for UI", recorder: recorder)
            expectEqual(providers.first?.modelAliases, ["glm5"], "model aliases should be extracted", recorder: recorder)
            expectEqual(providers.first?.inlineKeyCount, 1, "inline key count should deduplicate repeated config keys", recorder: recorder)
        }

        run("composeRuntimeConfig preserves user oauth exclusions", recorder: recorder) {
            let baseRoot: [String: Any] = [
                "oauth-excluded-models": [
                    "claude": ["claude-sonnet-4"],
                    "custom-oauth": ["x"]
                ]
            ]

            let runtime = ConfigComposer.composeRuntimeConfig(
                baseRoot: baseRoot,
                reservedCustomProviderKeys: reservedProviderIDs,
                disabledCustomProviderIDs: [],
                disabledOAuthProviderKeys: ["gemini-cli"],
                zaiAPIKeys: [],
                customProviderAuthRecords: [],
                includeManagedZAIProvider: false
            )

            let exclusions = dictionary(runtime["oauth-excluded-models"])
            expectEqual(stringArray(exclusions["claude"]), ["claude-sonnet-4"], "existing user claude exclusions should remain", recorder: recorder)
            expectEqual(stringArray(exclusions["custom-oauth"]), ["x"], "non-managed oauth exclusions should remain", recorder: recorder)
            expectEqual(stringArray(exclusions["gemini-cli"]), ["*"], "disabled managed provider should get wildcard exclusion", recorder: recorder)
        }

        run("composeRuntimeConfig strips UI metadata, deduplicates keys, and injects zai", recorder: recorder) {
            let baseRoot: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "display-name": "NVIDIA",
                        "help-text": "UI metadata",
                        "icon-system": "bolt.fill",
                        "base-url": "https://integrate.api.nvidia.com/v1",
                        "api-key-entries": [
                            ["api-key": "inline-a"],
                            ["api-key": "inline-b"]
                        ],
                        "models": [
                            ["name": "z-ai/glm5", "alias": "glm5"]
                        ]
                    ]
                ]
            ]

            let runtime = ConfigComposer.composeRuntimeConfig(
                baseRoot: baseRoot,
                reservedCustomProviderKeys: reservedProviderIDs,
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
            expectNil(nvidia?["display-name"], "runtime config should strip display-name", recorder: recorder)
            expectNil(nvidia?["help-text"], "runtime config should strip help-text", recorder: recorder)
            expectNil(nvidia?["icon-system"], "runtime config should strip icon-system", recorder: recorder)
            expectEqual(apiKeys(in: nvidia ?? [:]), ["inline-a", "inline-b", "auth-c"], "runtime keys should be deduplicated and exclude disabled auth records", recorder: recorder)

            let zai = provider(named: "zai", in: runtime)
            expectEqual(apiKeys(in: zai ?? [:]), ["zai-key-1"], "managed zai provider should be injected", recorder: recorder)
        }

        run("composeRuntimeConfig preserves user-authored zai models and merges inline plus managed keys", recorder: recorder) {
            let baseRoot: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "zai",
                        "display-name": "Z.AI",
                        "base-url": "https://api.z.ai/api/coding/paas/v4",
                        "api-key-entries": [
                            ["api-key": "inline-zai"]
                        ],
                        "models": [
                            ["name": "glm-4.7", "alias": "glm-4.7"],
                            ["name": "glm-5", "alias": "glm-5"],
                            ["name": "glm-5-turbo", "alias": "glm-5-turbo"]
                        ]
                    ]
                ]
            ]

            let runtime = ConfigComposer.composeRuntimeConfig(
                baseRoot: baseRoot,
                reservedCustomProviderKeys: reservedProviderIDs,
                disabledCustomProviderIDs: [],
                disabledOAuthProviderKeys: [],
                zaiAPIKeys: ["managed-zai", "inline-zai"],
                customProviderAuthRecords: [],
                includeManagedZAIProvider: true
            )

            let zai = provider(named: "zai", in: runtime)
            expectEqual(
                apiKeys(in: zai ?? [:]),
                ["inline-zai", "managed-zai"],
                "managed zai runtime should deduplicate inline and auth-file API keys",
                recorder: recorder
            )
            expectEqual(
                modelAliases(in: zai ?? [:]),
                ["glm-4.7", "glm-5", "glm-5-turbo"],
                "managed zai runtime should preserve user-authored model aliases",
                recorder: recorder
            )
            expectNil(
                zai?["display-name"],
                "managed zai runtime should strip UI metadata before writing merged config",
                recorder: recorder
            )
        }

        run("composeRuntimeConfig skips disabled custom providers", recorder: recorder) {
            let baseRoot: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "base-url": "https://integrate.api.nvidia.com/v1",
                        "models": [
                            ["name": "z-ai/glm5", "alias": "glm5"]
                        ]
                    ]
                ]
            ]

            let runtime = ConfigComposer.composeRuntimeConfig(
                baseRoot: baseRoot,
                reservedCustomProviderKeys: reservedProviderIDs,
                disabledCustomProviderIDs: ["nvidia"],
                disabledOAuthProviderKeys: [],
                zaiAPIKeys: [],
                customProviderAuthRecords: [
                    ConfigProviderAuthRecord(providerID: "nvidia", apiKey: "auth-a", isDisabled: false)
                ],
                includeManagedZAIProvider: false
            )

            expectNil(provider(named: "nvidia", in: runtime), "disabled custom providers should be omitted from runtime config", recorder: recorder)
        }

        run("wildcard oauth exclusions are detectable", recorder: recorder) {
            let root: [String: Any] = [
                "oauth-excluded-models": [
                    "claude": ["*"],
                    "gemini-cli": ["gemini-2.5-pro"]
                ]
            ]

            expectEqual(
                ConfigComposer.isOAuthProviderWildcardExcluded("claude", in: root),
                true,
                "wildcard exclusions should be detected for locked built-in providers",
                recorder: recorder
            )
            expectEqual(
                ConfigComposer.isOAuthProviderWildcardExcluded("gemini-cli", in: root),
                false,
                "specific model exclusions should not be treated as a full provider lock",
                recorder: recorder
            )
        }

        run("validateCustomProviders rejects missing or blank base-url values", recorder: recorder) {
            let root: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": "nvidia",
                        "base-url": "   "
                    ],
                    [
                        "name": "zai",
                        "base-url": ""
                    ]
                ]
            ]

            let validationErrors = ConfigComposer.validateCustomProviders(
                in: root,
                reservedProviderIDs: reservedProviderIDs
            )

            expectEqual(
                validationErrors,
                ["Custom provider 'nvidia' must define a non-empty base-url."],
                "only non-reserved custom providers with blank base-url should fail validation",
                recorder: recorder
            )
        }

        run("validateCustomProviders rejects malformed openai-compatibility shapes", recorder: recorder) {
            let malformedRoot: [String: Any] = [
                "openai-compatibility": [
                    "not-a-provider-mapping"
                ]
            ]
            let scalarRoot: [String: Any] = [
                "openai-compatibility": "not-an-array"
            ]

            let malformedErrors = ConfigComposer.validateCustomProviders(
                in: malformedRoot,
                reservedProviderIDs: reservedProviderIDs
            )
            let scalarErrors = ConfigComposer.validateCustomProviders(
                in: scalarRoot,
                reservedProviderIDs: reservedProviderIDs
            )

            expectEqual(
                malformedErrors,
                ["openai-compatibility[0] must be a mapping."],
                "non-mapping provider entries should fail loudly",
                recorder: recorder
            )
            expectEqual(
                scalarErrors,
                ["openai-compatibility must be an array of provider mappings."],
                "non-array openai-compatibility roots should fail loudly",
                recorder: recorder
            )
        }

        run("validateCustomProviders rejects non-canonical and reserved provider ids", recorder: recorder) {
            let root: [String: Any] = [
                "openai-compatibility": [
                    [
                        "name": " zai ",
                        "base-url": "https://api.z.ai/api/coding/paas/v4"
                    ],
                    [
                        "name": "gemini-cli",
                        "base-url": "https://example.com/v1"
                    ]
                ]
            ]

            let validationErrors = ConfigComposer.validateCustomProviders(
                in: root,
                reservedProviderIDs: reservedProviderIDs
            )

            expectEqual(
                validationErrors,
                [
                    "Provider name ' zai ' must not include leading or trailing whitespace.",
                    "Provider 'gemini-cli' is reserved and cannot be declared under openai-compatibility."
                ],
                "whitespace-padded and reserved provider ids should be rejected",
                recorder: recorder
            )
        }

        if recorder.failures == 0 {
            print("ConfigComposerSpec: all checks passed")
            Foundation.exit(EXIT_SUCCESS)
        }

        fputs("ConfigComposerSpec: \(recorder.failures) check(s) failed\n", stderr)
        Foundation.exit(EXIT_FAILURE)
    }
}

private final class FailureRecorder {
    var failures = 0
}

private func run(_ name: String, recorder: FailureRecorder, _ body: () -> Void) {
    let startingFailures = recorder.failures
    body()
    let status = recorder.failures == startingFailures ? "PASS" : "FAIL"
    print("[\(status)] \(name)")
}

private func expectEqual<T: Equatable>(
    _ actual: @autoclosure () -> T,
    _ expected: T,
    _ message: String,
    recorder: FailureRecorder
) {
    let value = actual()
    guard value == expected else {
        recorder.failures += 1
        fputs("  - \(message): expected \(expected), got \(value)\n", stderr)
        return
    }
}

private func expectNil(_ value: Any?, _ message: String, recorder: FailureRecorder) {
    guard value == nil else {
        recorder.failures += 1
        fputs("  - \(message): expected nil, got \(String(describing: value))\n", stderr)
        return
    }
}

private func providerEntries(in root: [String: Any]) -> [[String: Any]] {
    ConfigComposer.stringKeyedDictionaryArray(root["openai-compatibility"])
}

private func provider(named name: String, in root: [String: Any]) -> [String: Any]? {
    providerEntries(in: root).first { $0["name"] as? String == name }
}

private func dictionary(_ value: Any?) -> [String: Any] {
    guard let value else {
        return [:]
    }
    return ConfigComposer.stringKeyedDictionary(value) ?? [:]
}

private func stringArray(_ value: Any?) -> [String] {
    value as? [String] ?? []
}

private func apiKeys(in provider: [String: Any]) -> [String] {
    ConfigComposer.stringKeyedDictionaryArray(provider["api-key-entries"]).compactMap { $0["api-key"] as? String }
}

private func modelAliases(in provider: [String: Any]) -> [String] {
    ConfigComposer.stringKeyedDictionaryArray(provider["models"]).compactMap {
        ($0["alias"] as? String) ?? ($0["name"] as? String)
    }
}
