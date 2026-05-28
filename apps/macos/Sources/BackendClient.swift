import Foundation
import VibeProxyCore

/// Swift wrapper for the Rust BackendClient
/// Provides async/await interface for backend operations
class BackendClient {
    private let config: BackendConfig
    private let baseURL: URL
    
    init(config: BackendConfig) {
        self.config = config
        // Build URL from config
        let urlString = "\(config.url):\(config.port)"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid backend URL: \(urlString)")
        }
        self.baseURL = url
    }
    
    /// Check if the backend server is healthy
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("/health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
    
    /// Get backend status
    func getStatus() async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent("/api/v1/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "BackendClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        return json
    }
    
    /// Make a generic API request
    func request(path: String, method: String = "GET", body: Data? = nil) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            throw NSError(domain: "BackendClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"])
        }
        
        return data
    }
}
