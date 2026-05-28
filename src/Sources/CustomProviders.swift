import Foundation

struct CustomProviderDefinition: Identifiable, Equatable {
    let id: String
    let title: String
    let baseURL: String
    let helpText: String?
    let iconSystemName: String?
    let modelAliases: [String]
    let inlineAPIKeys: [String]

    var inlineKeyCount: Int {
        inlineAPIKeys.count
    }
    
    var effectiveHelpText: String {
        if let helpText, !helpText.isEmpty {
            return helpText
        }
        
        let modelSummary: String
        if modelAliases.isEmpty {
            modelSummary = "No model aliases configured yet."
        } else {
            modelSummary = "Models: \(modelAliases.joined(separator: ", "))."
        }
        
        return "OpenAI-compatible provider at \(baseURL). \(modelSummary)"
    }
    
    var effectiveIconSystemName: String {
        if let iconSystemName, !iconSystemName.isEmpty {
            return iconSystemName
        }
        return "server.rack"
    }
    
    static func defaultTitle(for id: String) -> String {
        let spaced = id.replacingOccurrences(
            of: "[^A-Za-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        let collapsed = spaced
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
        return collapsed.isEmpty ? id : collapsed
    }
}

struct CustomProviderCredential: Identifiable, Equatable {
    let providerID: String
    let apiKey: String
    let label: String
    let isDisabled: Bool

    var id: String {
        "\(providerID)|\(apiKey)"
    }
}
