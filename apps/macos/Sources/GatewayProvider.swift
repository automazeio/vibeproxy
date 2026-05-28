import Foundation

// ProviderTypeInfo represents metadata about a supported provider type
struct ProviderTypeInfo: Codable, Identifiable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String
    let authHeader: String
    let authPrefix: String
    let baseURL: String
    let docURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case description
        case authHeader = "auth_header"
        case authPrefix = "auth_prefix"
        case baseURL = "base_url"
        case docURL = "doc_url"
    }

    init(from decoder: Decoder) throws {
        self.id = UUID()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.description = try container.decode(String.self, forKey: .description)
        self.authHeader = try container.decode(String.self, forKey: .authHeader)
        self.authPrefix = try container.decode(String.self, forKey: .authPrefix)
        self.baseURL = try container.decode(String.self, forKey: .baseURL)
        self.docURL = try container.decode(String.self, forKey: .docURL)
    }
}

// ProviderModelInfo represents a model offered by a provider
struct ProviderModelInfo: Codable, Identifiable {
    let id: UUID
    let name: String
    let displayName: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case name
        case displayName = "display_name"
        case description
    }

    init(from decoder: Decoder) throws {
        self.id = UUID()
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.description = try container.decode(String.self, forKey: .description)
    }
}

// GatewayProvider represents a custom LLM provider configuration
struct GatewayProvider: Codable, Identifiable {
    let id: String
    var name: String
    var type: String
    var baseURL: String
    var apiKey: String
    var headers: [String: String]?
    var models: [GatewayProviderModel]?

    enum CodingKeys: String, CodingKey {
        case name
        case type
        case baseURL = "base-url"
        case apiKey = "api-key"
        case headers
        case models
    }

    init(name: String, type: String, baseURL: String, apiKey: String, headers: [String: String]? = nil, models: [GatewayProviderModel]? = nil) {
        self.id = UUID().uuidString
        self.name = name
        self.type = type
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.headers = headers
        self.models = models
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID().uuidString
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.baseURL = try container.decode(String.self, forKey: .baseURL)
        self.apiKey = try container.decode(String.self, forKey: .apiKey)
        self.headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        self.models = try container.decodeIfPresent([GatewayProviderModel].self, forKey: .models)
    }
}

// GatewayProviderModel represents a model mapping for a provider
struct GatewayProviderModel: Codable {
    var name: String
    var alias: String
}

// Note: ProviderType enum removed - now fetched dynamically from API
// Use ProviderTypeInfo from CLIProxyAPI.fetchProviderTypes() instead
