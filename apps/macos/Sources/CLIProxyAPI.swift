import Foundation

// Model structure for service models
struct ModelInfo: Codable {
    let name: String
    let displayName: String?
    let description: String?
    let maxTokens: Int?
    let contextWindow: Int?
    let supportsStreaming: Bool?
}

// Service info structure for service discovery
struct ServiceDiscoveryInfo: Codable {
    let id: String
    let name: String
    let displayName: String
    let icon: String?
    let provider: String
    let isConfigBased: Bool
    let modelCount: Int
    let available: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case displayName = "display_name"
        case icon
        case provider
        case isConfigBased = "is_config_based"
        case modelCount = "model_count"
        case available
    }
}

// Wrapper for services response
struct ServicesResponse: Codable {
    let services: [ServiceDiscoveryInfo]
    let count: Int
}

// Result type for model discovery
enum ModelDiscoveryResult {
    case success([ModelInfo])
    case failure(Error)
}

// Result type for service discovery
enum ServiceDiscoveryResult {
    case success([ServiceDiscoveryInfo])
    case failure(Error)
}

// MARK: - SLM Types

/// SLM status response from gateway
struct SLMStatus: Codable {
    let running: Bool
    let backend: String?
    let model: String?
    let port: Int?
    let uptime: TimeInterval?
    let requestsServed: Int?
    let avgLatencyMs: Double?
    let error: String?
}

/// SLM configuration for starting backend (API-specific, different from VibeProxyCore.SLMConfig)
struct APISLMConfig: Codable {
    let backend: String
    let model: String
    let port: Int
    let host: String
    let maxContextLength: Int?
    let quantization: String?
    let customArgs: [String]?
    
    enum CodingKeys: String, CodingKey {
        case backend
        case model
        case port
        case host
        case maxContextLength = "max_context_length"
        case quantization
        case customArgs = "custom_args"
    }
}

/// SLM model information
struct SLMModelInfo: Codable, Identifiable {
    let id: String
    let name: String
    let author: String?
    let backend: String
    let size: String?
    let quantization: String?
    let isInstalled: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case author
        case backend
        case size
        case quantization
        case isInstalled = "is_installed"
    }
}

// CLI Proxy API client for model discovery
// Now uses shared core BackendClient
class CLIProxyAPI {
    static let shared = CLIProxyAPI()
    
    private var backendClient: BackendClient?
    private let session = URLSession.shared
    private var baseURL: String {
        let config = ConfigManager.shared.getConfig()
        return "\(config.backend.url):\(config.backend.port)"
    }
    
    private init() {
        // Initialize with config from shared core
        let config = ConfigManager.shared.getConfig()
        self.backendClient = BackendClient(config: config.backend)
    }
    
    /// Update backend client when config changes
    func updateConfig() {
        let config = ConfigManager.shared.getConfig()
        self.backendClient = BackendClient(config: config.backend)
    }
    
    /// Get available models for a specific service
    func getAvailableModels(for service: String, completion: @escaping (ModelDiscoveryResult) -> Void) {
        guard let client = backendClient else {
            // Fallback to hardcoded models if client not initialized
            let fallbackModels = getFallbackModels(for: service)
            completion(.success(fallbackModels))
            return
        }
        
        Task {
            do {
                let data = try await client.request(path: "/api/services/\(service)/models", method: "GET")
                let decoder = JSONDecoder()
                let models = try decoder.decode([ModelInfo].self, from: data)
                await MainActor.run {
                    completion(.success(models))
                }
            } catch {
                // Fallback to hardcoded models on error
                let fallbackModels = getFallbackModels(for: service)
                await MainActor.run {
                    completion(.success(fallbackModels))
                }
            }
        }
    }
    
    /// Legacy synchronous method (deprecated, use async version)
    private func getAvailableModelsSync(for service: String, completion: @escaping (ModelDiscoveryResult) -> Void) {
        guard let client = backendClient else {
            let fallbackModels = getFallbackModels(for: service)
            completion(.success(fallbackModels))
            return
        }
        
        let config = ConfigManager.shared.getConfig()
        let baseURL = "\(config.backend.url):\(config.backend.port)"
        let endpoint = "\(baseURL)/api/services/\(service)/models"
        guard let url = URL(string: endpoint) else {
            let error = NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        if let apiKey = config.backend.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        do {
                            let decoder = JSONDecoder()
                            let models = try decoder.decode([ModelInfo].self, from: data)
                            completion(.success(models))
                        } catch {
                            completion(.failure(error))
                        }
                    } else {
                        let models = self.getFallbackModels(for: service)
                        completion(.success(models))
                    }
                } else {
                    // Try fallback models for common services
                    let fallbackModels = self.getFallbackModels(for: service)
                    completion(.success(fallbackModels))
                }
            }
        }
        
        task.resume()
    }
    
    /// Get fallback models when API is not available
    private func getFallbackModels(for service: String) -> [ModelInfo] {
        switch service.lowercased() {
        case "claude":
            return [
                ModelInfo(name: "claude-haiku-4-5-20251001", 
                         displayName: "Claude 4.5 Haiku", 
                         description: "Fast, lightweight Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-sonnet-4-5-20250929", 
                         displayName: "Claude 4.5 Sonnet", 
                         description: "Advanced reasoning Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-opus-4-1-20250805", 
                         displayName: "Claude 4.1 Opus", 
                         description: "Most powerful Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-opus-4-20250514", 
                         displayName: "Claude 4 Opus", 
                         description: "Previous generation powerful Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-sonnet-4-20250514", 
                         displayName: "Claude 4 Sonnet", 
                         description: "Balanced performance Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-3-7-sonnet-20250219", 
                         displayName: "Claude 3.7 Sonnet", 
                         description: "Previous generation advanced Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "claude-3-5-haiku-20241022", 
                         displayName: "Claude 3.5 Haiku", 
                         description: "Previous generation lightweight Claude model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true)
            ]
        case "openai", "codex":
            return [
                ModelInfo(name: "gpt-4o", 
                         displayName: "GPT-4o", 
                         description: "Most capable model with vision and audio", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "gpt-4o-mini", 
                         displayName: "GPT-4o Mini", 
                         description: "Fast and cost-effective with vision", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "gpt-4-turbo", 
                         displayName: "GPT-4 Turbo", 
                         description: "Latest GPT-4 model with function calling", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "gpt-3.5-turbo", 
                         displayName: "GPT-3.5 Turbo", 
                         description: "Fast and affordable for simple tasks", 
                         maxTokens: 16385,
                         contextWindow: 16385,
                         supportsStreaming: true)
            ]
        case "gemini":
            return [
                ModelInfo(name: "gemini-1.5-pro", 
                         displayName: "Gemini 1.5 Pro", 
                         description: "Most capable Gemini model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "gemini-1.5-flash", 
                         displayName: "Gemini 1.5 Flash", 
                         description: "Fast and efficient model", 
                         maxTokens: 100000,
                         contextWindow: 100000,
                         supportsStreaming: true),
                ModelInfo(name: "gemini-pro", 
                         displayName: "Gemini Pro", 
                         description: "Previous generation high-quality model", 
                         maxTokens: 32000,
                         contextWindow: 32000,
                         supportsStreaming: true)
            ]
        case "qwen":
            return [
                ModelInfo(name: "qwen-max", 
                         displayName: "Qwen Max", 
                         description: "Most capable Qwen model", 
                         maxTokens: 8192,
                         contextWindow: 8192,
                         supportsStreaming: true),
                ModelInfo(name: "qwen-plus", 
                         displayName: "Qwen Plus", 
                         description: "Balanced performance and cost", 
                         maxTokens: 8192,
                         contextWindow: 8192,
                         supportsStreaming: true),
                ModelInfo(name: "qwen-turbo", 
                         displayName: "Qwen Turbo", 
                         description: "Fast and cost-effective", 
                         maxTokens: 8192,
                         contextWindow: 8192,
                         supportsStreaming: true)
            ]
        case "auggie":
            return [
                ModelInfo(name: "auggie-haiku4.5", 
                         displayName: "Auggie Claude Haiku 4.5", 
                         description: "Anthropic Claude Haiku 4.5", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: false),
                ModelInfo(name: "auggie-sonnet4", 
                         displayName: "Auggie Claude Sonnet 4", 
                         description: "Anthropic Claude Sonnet 4", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: false),
                ModelInfo(name: "auggie-sonnet4.5", 
                         displayName: "Auggie Claude Sonnet 4.5", 
                         description: "Anthropic Claude Sonnet 4.5", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: false),
                ModelInfo(name: "auggie-gpt5", 
                         displayName: "Auggie GPT-5", 
                         description: "OpenAI GPT-5 legacy", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: false),
                ModelInfo(name: "auggie-gpt5.1", 
                         displayName: "Auggie GPT-5.1", 
                         description: "OpenAI GPT-5.1", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: false)
            ]
        case "cursor":
            return [
                ModelInfo(name: "cursor-auto", 
                         displayName: "Cursor Agent (Auto)", 
                         description: "Automatic model selection", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-composer-1", 
                         displayName: "Composer 1", 
                         description: "Cursor's Composer model", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-sonnet-4.5", 
                         displayName: "Claude Sonnet 4.5", 
                         description: "Anthropic Claude Sonnet 4.5", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-sonnet-4.5-thinking", 
                         displayName: "Claude Sonnet 4.5 Thinking", 
                         description: "Claude Sonnet 4.5 with thinking", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gemini-3-pro", 
                         displayName: "Gemini 3 Pro", 
                         description: "Google Gemini 3 Pro", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5", 
                         displayName: "GPT-5", 
                         description: "OpenAI GPT-5", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5.1", 
                         displayName: "GPT-5.1", 
                         description: "OpenAI GPT-5.1", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5-high", 
                         displayName: "GPT-5 High", 
                         description: "OpenAI GPT-5 with high context", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5.1-high", 
                         displayName: "GPT-5.1 High", 
                         description: "OpenAI GPT-5.1 with high context", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5-codex", 
                         displayName: "GPT-5 Codex", 
                         description: "OpenAI GPT-5 Codex for code", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5-codex-high", 
                         displayName: "GPT-5 Codex High", 
                         description: "OpenAI GPT-5 Codex with high context", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5.1-codex", 
                         displayName: "GPT-5.1 Codex", 
                         description: "OpenAI GPT-5.1 Codex for code", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-gpt-5.1-codex-high", 
                         displayName: "GPT-5.1 Codex High", 
                         description: "OpenAI GPT-5.1 Codex with high context", 
                         maxTokens: 128000,
                         contextWindow: 128000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-opus-4.1", 
                         displayName: "Claude Opus 4.1", 
                         description: "Anthropic Claude Opus 4.1", 
                         maxTokens: 200000,
                         contextWindow: 200000,
                         supportsStreaming: true),
                ModelInfo(name: "cursor-grok", 
                         displayName: "Grok", 
                         description: "xAI Grok", 
                         maxTokens: 100000,
                         contextWindow: 100000,
                         supportsStreaming: true)
            ]
        default:
            return [
                ModelInfo(name: "default", 
                         displayName: "Default Model", 
                         description: "Generic model for unknown services", 
                         maxTokens: 4096,
                         contextWindow: 4096,
                         supportsStreaming: true)
            ]
        }
    }
    
    /// Get all available services
    func getAvailableServices(completion: @escaping (ServiceDiscoveryResult) -> Void) {
        let endpoint = "\(baseURL)/api/v1/services"
        guard let url = URL(string: endpoint) else {
            let error = NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
            completion(.failure(error))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    let error = NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                    completion(.failure(error))
                    return
                }
                
                if httpResponse.statusCode == 200, let data = data {
                    do {
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(ServicesResponse.self, from: data)
                        completion(.success(response.services))
                    } catch {
                        completion(.failure(error))
                    }
                } else {
                    let error = NSError(domain: "CLIProxyAPI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch services"])
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    /// Get a specific service by ID
    func getService(id: String, completion: @escaping (ServiceDiscoveryInfo?) -> Void) {
        let endpoint = "\(baseURL)/api/v1/services/\(id)"
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Failed to fetch service \(id): \(error)")
                    completion(nil)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data else {
                    completion(nil)
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let service = try decoder.decode(ServiceDiscoveryInfo.self, from: data)
                    completion(service)
                } catch {
                    print("Failed to decode service \(id): \(error)")
                    completion(nil)
                }
            }
        }
        
        task.resume()
    }
    
    /// Check if the CLI Proxy API is running
    func isAPIAvailable(completion: @escaping (Bool) -> Void) {
        let endpoint = "\(baseURL)/api/health"
        guard let url = URL(string: endpoint) else {
            completion(false)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("CLI Proxy API health check failed: \(error)")
                    completion(false)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false)
                    return
                }
                
                completion(httpResponse.statusCode == 200)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Gateway Provider Management
    
    /// Fetch all available provider types from the API
    func fetchProviderTypes(completion: @escaping ([ProviderTypeInfo]?, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/provider-types"
        guard let url = URL(string: endpoint) else {
            completion(nil, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let data = data else {
                    completion([], nil)
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode([String: [ProviderTypeInfo]].self, from: data)
                    completion(response["providers"] ?? [], nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// Fetch available models for a specific provider type
    func fetchProviderModels(for providerType: String, completion: @escaping ([ProviderModelInfo]?, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/provider-models?type=\(providerType)"
        guard let url = URL(string: endpoint) else {
            completion(nil, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let data = data else {
                    completion([], nil)
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode([String: [ProviderModelInfo]].self, from: data)
                    completion(response["models"] ?? [], nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// Fetch all gateway providers from CLIProxyAPI
    func fetchGatewayProviders(completion: @escaping ([GatewayProvider]?, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/providers"
        guard let url = URL(string: endpoint) else {
            completion(nil, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }
                
                guard let data = data else {
                    completion([], nil)
                    return
                }
                
                do {
                    let decoder = JSONDecoder()
                    let response = try decoder.decode([String: [GatewayProvider]].self, from: data)
                    completion(response["providers"] ?? [], nil)
                } catch {
                    completion(nil, error)
                }
            }
        }
        
        task.resume()
    }
    
    /// Add a new gateway provider
    func addGatewayProvider(_ provider: GatewayProvider, completion: @escaping (Bool, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/providers"
        guard let url = URL(string: endpoint) else {
            completion(false, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        do {
            let body = ["provider": provider]
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            completion(false, error)
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }
                
                completion(httpResponse.statusCode == 200, nil)
            }
        }
        
        task.resume()
    }
    
    /// Update an existing gateway provider
    func updateGatewayProvider(_ provider: GatewayProvider, completion: @escaping (Bool, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/providers"
        guard let url = URL(string: endpoint) else {
            completion(false, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0
        
        do {
            request.httpBody = try JSONEncoder().encode(provider)
        } catch {
            completion(false, error)
            return
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }
                
                completion(httpResponse.statusCode == 200, nil)
            }
        }
        
        task.resume()
    }
    
    /// Delete a gateway provider
    func deleteGatewayProvider(name: String, completion: @escaping (Bool, Error?) -> Void) {
        let endpoint = "\(baseURL)/v0/management/gateway/providers?name=\(name)"
        guard let url = URL(string: endpoint) else {
            completion(false, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
                    return
                }

                completion(httpResponse.statusCode == 200, nil)
            }
        }

        task.resume()
    }

    /// Get generated rules from learning system
    func getGeneratedRules(completion: @escaping ([String: Any]?, Error?) -> Void) {
        let endpoint = "\(baseURL)/api/v1/learning/rules"
        guard let url = URL(string: endpoint) else {
            completion(nil, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }

                guard let data = data else {
                    completion(nil, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        completion(json, nil)
                    } else {
                        completion(nil, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                    }
                } catch {
                    completion(nil, error)
                }
            }
        }

        task.resume()
    }

    /// Authenticate a service generically
    func authenticateService(_ serviceId: String, completion: @escaping (Bool, String?) -> Void) {
        let endpoint = "\(baseURL)/api/v1/auth/\(serviceId)"
        guard let url = URL(string: endpoint) else {
            completion(false, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    completion(false, "Invalid response")
                    return
                }

                if httpResponse.statusCode == 200 {
                    completion(true, "✓ \(serviceId) authenticated successfully")
                } else {
                    completion(false, "✗ Authentication failed with status \(httpResponse.statusCode)")
                }
            }
        }

        task.resume()
    }

    /// Get recommended models from learning system
    func getRecommendedModels(completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let endpoint = "\(baseURL)/api/v1/learning/recommendations"
        guard let url = URL(string: endpoint) else {
            completion(nil, NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0

        let task = session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(nil, error)
                    return
                }

                guard let data = data else {
                    completion(nil, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"]))
                    return
                }

                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let recommendations = json["recommendations"] as? [[String: Any]] {
                        completion(recommendations, nil)
                    } else {
                        completion(nil, NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response format"]))
                    }
                } catch {
                    completion(nil, error)
                }
            }
        }

        task.resume()
    }

    // MARK: - SLM Endpoints

    /// Get SLM status from the gateway
    func getSLMStatus(completion: @escaping (Result<SLMStatus, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/slm/status"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }

                do {
                    let status = try JSONDecoder().decode(SLMStatus.self, from: data)
                    completion(.success(status))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    /// Start SLM backend via gateway
    func startSLM(config: APISLMConfig, completion: @escaping (Result<Bool, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/slm/start"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(config)
        request.timeoutInterval = 30.0

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                completion(.success(statusCode == 200 || statusCode == 201))
            }
        }.resume()
    }

    /// Stop SLM backend via gateway
    func stopSLM(completion: @escaping (Result<Bool, Error>) -> Void) {
        let endpoint = "\(baseURL)/api/slm/stop"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 500
                completion(.success(statusCode == 200))
            }
        }.resume()
    }

    /// Get available SLM models
    func getSLMModels(backend: String, completion: @escaping (Result<[SLMModelInfo], Error>) -> Void) {
        let endpoint = "\(baseURL)/api/slm/models?backend=\(backend)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "CLIProxyAPI", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0

        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }

                guard let data = data else {
                    completion(.failure(NSError(domain: "CLIProxyAPI", code: 500, userInfo: [NSLocalizedDescriptionKey: "No data"])))
                    return
                }

                do {
                    let models = try JSONDecoder().decode([SLMModelInfo].self, from: data)
                    completion(.success(models))
                } catch {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}
