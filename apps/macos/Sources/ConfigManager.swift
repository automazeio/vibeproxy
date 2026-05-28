import Foundation
import VibeProxyCore

/// Manages application configuration using shared core
class ConfigManager {
    static let shared = ConfigManager()
    
    private var appConfig: AppConfig?
    private let configURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("VibeProxy", isDirectory: true)
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
        
        configURL = configDir.appendingPathComponent("config.json")
    }
    
    /// Load configuration from shared core default or file
    func loadConfig() -> AppConfig {
        // Try to load from file first
        if let data = try? Data(contentsOf: configURL),
           let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            appConfig = config
            return config
        }
        
        // Fall back to shared core default
        let defaultConfig = VibeProxyCore.defaultConfig()
        appConfig = defaultConfig
        return defaultConfig
    }
    
    /// Save configuration to file
    func saveConfig(_ config: AppConfig) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configURL)
        appConfig = config
    }
    
    /// Get current configuration
    func getConfig() -> AppConfig {
        if let config = appConfig {
            return config
        }
        return loadConfig()
    }
    
    /// Update backend configuration
    func updateBackend(_ backend: BackendConfig) throws {
        var config = getConfig()
        config.backend = backend
        try saveConfig(config)
    }
    
    /// Update SLM configuration
    func updateSLM(_ slm: SLMConfig) throws {
        var config = getConfig()
        config.slm = slm
        try saveConfig(config)
    }
    
    /// Update tunnel configuration
    func updateTunnel(_ tunnel: TunnelConfig) throws {
        var config = getConfig()
        config.tunnel = tunnel
        try saveConfig(config)
    }
}
