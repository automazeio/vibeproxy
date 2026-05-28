import Foundation

struct ConfigProviderAuthRecord: Equatable {
    let providerID: String
    let apiKey: String
    let isDisabled: Bool
}

enum ConfigComposer {
    static let uiMetadataKeys: Set<String> = ["display-name", "help-text", "icon-system"]
    static let runtimeEditableTopLevelKeys: Set<String> = ["api-keys"]
    
    static func composeAdditiveBaseConfig(bundledRoot: [String: Any], userRoot: [String: Any]?) -> [String: Any] {
        guard let userRoot else {
            return bundledRoot
        }
        return mergeDictionary(bundledRoot, overlaidWith: userRoot)
    }

    static func preservingRuntimeEditableTopLevelKeys(
        in root: [String: Any],
        from runtimeRoot: [String: Any]?
    ) -> [String: Any] {
        guard let runtimeRoot else {
            return root
        }

        var mergedRoot = root
        for key in runtimeEditableTopLevelKeys where mergedRoot[key] == nil {
            if let runtimeValue = runtimeRoot[key] {
                mergedRoot[key] = runtimeValue
            }
        }
        return mergedRoot
    }
    
    static func parseCustomProviders(
        from root: [String: Any],
        reservedProviderIDs: Set<String>
    ) -> [CustomProviderDefinition] {
        stringKeyedDictionaryArray(root["openai-compatibility"])
            .compactMap { entry in
                guard let providerID = normalizedProviderID(from: entry),
                      !reservedProviderIDs.contains(providerID) else {
                    return nil
                }
                
                let modelAliases = stringKeyedDictionaryArray(entry["models"])
                    .compactMap { model in
                        (model["alias"] as? String) ?? (model["name"] as? String)
                    }
                return CustomProviderDefinition(
                    id: providerID,
                    title: (entry["display-name"] as? String) ?? CustomProviderDefinition.defaultTitle(for: providerID),
                    baseURL: normalizedString(entry["base-url"]) ?? "",
                    helpText: entry["help-text"] as? String,
                    iconSystemName: entry["icon-system"] as? String,
                    modelAliases: modelAliases,
                    inlineAPIKeys: deduplicatedAPIKeys(from: entry)
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    static func validateCustomProviders(
        in root: [String: Any],
        reservedProviderIDs: Set<String>
    ) -> [String] {
        guard let rawOpenAICompatibility = root["openai-compatibility"] else {
            return []
        }
        guard let entries = rawOpenAICompatibility as? [Any] else {
            return ["openai-compatibility must be an array of provider mappings."]
        }

        var errors: [String] = []
        var seenProviderIDs: Set<String> = []

        for (index, rawEntry) in entries.enumerated() {
            let path = "openai-compatibility[\(index)]"

            guard let entry = stringKeyedDictionary(rawEntry) else {
                errors.append("\(path) must be a mapping.")
                continue
            }

            guard let rawProviderName = entry["name"] as? String else {
                errors.append("\(path) must define a string name.")
                continue
            }

            guard let providerID = normalizedString(rawProviderName) else {
                errors.append("\(path) must define a non-empty name.")
                continue
            }

            guard rawProviderName == providerID else {
                errors.append("Provider name '\(rawProviderName)' must not include leading or trailing whitespace.")
                continue
            }

            if seenProviderIDs.contains(providerID) {
                errors.append("Duplicate openai-compatibility provider '\(providerID)' is not allowed.")
            } else {
                seenProviderIDs.insert(providerID)
            }

            if reservedProviderIDs.contains(providerID), providerID != ProviderCatalog.managedZAIProviderName {
                errors.append("Provider '\(providerID)' is reserved and cannot be declared under openai-compatibility.")
                continue
            }

            if let modelsValue = entry["models"] {
                errors.append(contentsOf: validateMappingArray(modelsValue, path: "\(path).models"))
            }

            if let apiKeyEntriesValue = entry["api-key-entries"] {
                if let apiKeyEntries = apiKeyEntriesValue as? [Any] {
                    for (apiKeyIndex, rawAPIKeyEntry) in apiKeyEntries.enumerated() {
                        let apiKeyPath = "\(path).api-key-entries[\(apiKeyIndex)]"
                        guard let apiKeyEntry = stringKeyedDictionary(rawAPIKeyEntry) else {
                            errors.append("\(apiKeyPath) must be a mapping.")
                            continue
                        }
                        guard normalizedString(apiKeyEntry["api-key"]) != nil else {
                            errors.append("\(apiKeyPath) must define a non-empty api-key.")
                            continue
                        }
                    }
                } else {
                    errors.append("\(path).api-key-entries must be an array of mappings.")
                }
            }

            if providerID == ProviderCatalog.managedZAIProviderName {
                continue
            }

            guard normalizedString(entry["base-url"]) != nil else {
                errors.append("Custom provider '\(providerID)' must define a non-empty base-url.")
                continue
            }
        }

        return errors
    }
    
    static func composeRuntimeConfig(
        baseRoot: [String: Any],
        reservedCustomProviderKeys: Set<String>,
        disabledCustomProviderIDs: Set<String>,
        disabledOAuthProviderKeys: [String],
        zaiAPIKeys: [String],
        customProviderAuthRecords: [ConfigProviderAuthRecord],
        includeManagedZAIProvider: Bool,
        managedZAIProviderName: String = "zai"
    ) -> [String: Any] {
        var mergedRoot = baseRoot
        
        let oauthExcludedModels = buildOAuthExcludedModels(
            from: mergedRoot["oauth-excluded-models"],
            disabledOAuthProviderKeys: disabledOAuthProviderKeys
        )
        if let oauthExcludedModels {
            mergedRoot["oauth-excluded-models"] = oauthExcludedModels
        } else {
            mergedRoot.removeValue(forKey: "oauth-excluded-models")
        }
        
        let managedCustomProviderIDs = Set(
            parseCustomProviders(from: baseRoot, reservedProviderIDs: reservedCustomProviderKeys).map(\.id)
        )
        let authEntriesByProviderID = Dictionary(
            grouping: customProviderAuthRecords.filter { !$0.isDisabled },
            by: \.providerID
        ).mapValues { records in
            records.map { ["api-key": $0.apiKey] }
        }
        
        var mergedOpenAICompatibility: [[String: Any]] = []
        var managedZAIBaseEntry: [String: Any]?
        for entry in stringKeyedDictionaryArray(mergedRoot["openai-compatibility"]) {
            guard let providerName = normalizedProviderID(from: entry) else {
                continue
            }

            var sanitizedEntry = stripCustomProviderUIMetadata(from: entry)
            sanitizedEntry["name"] = providerName
            if providerName == managedZAIProviderName {
                managedZAIBaseEntry = sanitizedEntry
                continue
            }
            
            if managedCustomProviderIDs.contains(providerName) {
                if disabledCustomProviderIDs.contains(providerName) {
                    continue
                }
                
                let inlineEntries = apiKeyEntries(from: entry)
                let authEntries = authEntriesByProviderID[providerName] ?? []
                let effectiveEntries = deduplicatedAPIKeyEntries(inlineEntries + authEntries)
                guard !effectiveEntries.isEmpty else {
                    continue
                }
                sanitizedEntry["api-key-entries"] = effectiveEntries
            }
            
            mergedOpenAICompatibility.append(sanitizedEntry)
        }
        
        if includeManagedZAIProvider {
            let managedZAIEntry = makeZAIProviderEntry(
                baseEntry: managedZAIBaseEntry,
                apiKeys: zaiAPIKeys
            )
            if !apiKeyEntries(from: managedZAIEntry).isEmpty {
                mergedOpenAICompatibility.append(managedZAIEntry)
            }
        }
        
        if mergedOpenAICompatibility.isEmpty {
            mergedRoot.removeValue(forKey: "openai-compatibility")
        } else {
            mergedRoot["openai-compatibility"] = mergedOpenAICompatibility
        }
        
        return mergedRoot
    }
    
    static func stringKeyedDictionary(_ value: Any) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? [AnyHashable: Any] {
            var stringDictionary: [String: Any] = [:]
            for (key, nestedValue) in dictionary {
                guard let stringKey = key as? String else {
                    continue
                }
                stringDictionary[stringKey] = nestedValue
            }
            return stringDictionary
        }
        return nil
    }
    
    static func stringKeyedDictionaryArray(_ value: Any?) -> [[String: Any]] {
        guard let array = value as? [Any] else {
            return []
        }
        return array.compactMap { stringKeyedDictionary($0) }
    }

    static func stringArray(_ value: Any?) -> [String] {
        if let array = value as? [String] {
            return array
        }
        if let array = value as? [Any] {
            return array.compactMap { $0 as? String }
        }
        return []
    }

    static func normalizedString(_ value: Any?) -> String? {
        guard let string = value as? String else {
            return nil
        }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func isOAuthProviderWildcardExcluded(_ oauthProviderKey: String, in root: [String: Any]) -> Bool {
        let exclusions = stringKeyedDictionary(root["oauth-excluded-models"] ?? [:]) ?? [:]
        return stringArray(exclusions[oauthProviderKey]).contains("*")
    }
    
    private static func mergeDictionary(_ base: [String: Any], overlaidWith overlay: [String: Any]) -> [String: Any] {
        var merged = base
        
        for (key, overlayValue) in overlay {
            if key == "openai-compatibility" {
                if let overlayArray = overlayValue as? [Any] {
                    guard !overlayArray.isEmpty else {
                        continue
                    }

                    let overlayEntries = overlayArray.compactMap { stringKeyedDictionary($0) }
                    if overlayEntries.isEmpty {
                        merged[key] = overlayValue
                    } else {
                        let baseEntries = stringKeyedDictionaryArray(merged[key])
                        merged[key] = mergeNamedEntries(base: baseEntries, overlay: overlayEntries)
                    }
                } else {
                    merged[key] = overlayValue
                }
                continue
            }
            
            if let overlayDictionary = stringKeyedDictionary(overlayValue),
               let baseDictionary = merged[key].flatMap(stringKeyedDictionary) {
                merged[key] = mergeDictionary(baseDictionary, overlaidWith: overlayDictionary)
            } else {
                merged[key] = overlayValue
            }
        }
        
        return merged
    }
    
    private static func mergeNamedEntries(base: [[String: Any]], overlay: [[String: Any]]) -> [[String: Any]] {
        var mergedEntries = base
        var indexByName: [String: Int] = [:]
        
        for (index, entry) in base.enumerated() {
            if let name = normalizedProviderID(from: entry) {
                indexByName[name] = index
                if (mergedEntries[index]["name"] as? String) != name {
                    mergedEntries[index]["name"] = name
                }
            }
        }
        
        for overlayEntry in overlay {
            guard let name = normalizedProviderID(from: overlayEntry) else {
                mergedEntries.append(overlayEntry)
                continue
            }

            var canonicalOverlayEntry = overlayEntry
            canonicalOverlayEntry["name"] = name
            
            if let existingIndex = indexByName[name] {
                let existingEntry = mergedEntries[existingIndex]
                mergedEntries[existingIndex] = mergeDictionary(existingEntry, overlaidWith: canonicalOverlayEntry)
            } else {
                indexByName[name] = mergedEntries.count
                mergedEntries.append(canonicalOverlayEntry)
            }
        }
        
        return mergedEntries
    }
    
    private static func apiKeyEntries(from entry: [String: Any]) -> [[String: String]] {
        stringKeyedDictionaryArray(entry["api-key-entries"]).compactMap { keyEntry in
            guard let apiKey = normalizedString(keyEntry["api-key"]) else {
                return nil
            }
            return ["api-key": apiKey]
        }
    }

    private static func deduplicatedAPIKeys(from entry: [String: Any]) -> [String] {
        deduplicatedAPIKeyEntries(apiKeyEntries(from: entry)).compactMap { $0["api-key"] }
    }
    
    private static func deduplicatedAPIKeyEntries(_ entries: [[String: String]]) -> [[String: String]] {
        var seen: Set<String> = []
        return entries.filter { entry in
            guard let apiKey = entry["api-key"] else {
                return false
            }
            if seen.contains(apiKey) {
                return false
            }
            seen.insert(apiKey)
            return true
        }
    }
    
    private static func stripCustomProviderUIMetadata(from entry: [String: Any]) -> [String: Any] {
        var sanitized = entry
        for key in uiMetadataKeys {
            sanitized.removeValue(forKey: key)
        }
        return sanitized
    }
    
    private static func buildOAuthExcludedModels(
        from value: Any?,
        disabledOAuthProviderKeys: [String]
    ) -> [String: Any]? {
        var merged = stringKeyedDictionary(value ?? [:]) ?? [:]
        for providerKey in disabledOAuthProviderKeys.sorted() {
            merged[providerKey] = ["*"]
        }
        return merged.isEmpty ? nil : merged
    }
    
    private static func makeZAIProviderEntry(baseEntry: [String: Any]?, apiKeys: [String]) -> [String: Any] {
        var entry = stripCustomProviderUIMetadata(from: baseEntry ?? [:])
        entry["name"] = "zai"

        if normalizedString(entry["base-url"]) == nil {
            entry["base-url"] = "https://api.z.ai/api/coding/paas/v4"
        }

        let inlineEntries = apiKeyEntries(from: entry)
        entry["api-key-entries"] = deduplicatedAPIKeyEntries(
            inlineEntries + apiKeys.map { ["api-key": $0] }
        )

        if stringKeyedDictionaryArray(entry["models"]).isEmpty {
            entry["models"] = defaultZAIModels()
        }

        return entry
    }

    private static func normalizedProviderID(from entry: [String: Any]) -> String? {
        normalizedString(entry["name"])
    }

    private static func validateMappingArray(_ value: Any, path: String) -> [String] {
        guard let array = value as? [Any] else {
            return ["\(path) must be an array of mappings."]
        }

        var errors: [String] = []
        for (index, rawEntry) in array.enumerated() where stringKeyedDictionary(rawEntry) == nil {
            errors.append("\(path)[\(index)] must be a mapping.")
        }
        return errors
    }

    private static func defaultZAIModels() -> [[String: String]] {
        [
            ["name": "glm-4.7", "alias": "glm-4.7"],
            ["name": "glm-4-plus", "alias": "glm-4-plus"],
            ["name": "glm-4-air", "alias": "glm-4-air"],
            ["name": "glm-4-flash", "alias": "glm-4-flash"]
        ]
    }
}
