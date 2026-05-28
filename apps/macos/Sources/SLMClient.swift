import Foundation
import VibeProxyCore

/// Swift wrapper for the Rust SLMClient
/// Provides async/await interface for SLM server operations
class SLMClient {
    private let config: SLMConfig
    private let baseURL: URL
    
    init(config: SLMConfig) {
        self.config = config
        // Build URL from config (VibeProxyCore.SLMConfig has url and port properties)
        let urlString = "\(config.url):\(config.port)"
        guard let url = URL(string: urlString) else {
            fatalError("Invalid SLM URL: \(urlString)")
        }
        self.baseURL = url
    }
    
    /// Check if the SLM server is healthy
    func healthCheck() async throws -> Bool {
        let url = baseURL.appendingPathComponent("/health")
        let request = URLRequest(url: url)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            return httpResponse.statusCode == 200
        }
        return false
    }
    
    /// Get SLM server status
    func getStatus() async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent("/api/v1/status")
        let request = URLRequest(url: url)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "SLMClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON response"])
        }
        
        return json
    }
}
