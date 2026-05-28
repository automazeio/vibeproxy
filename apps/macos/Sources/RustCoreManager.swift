import Foundation
import Combine
import VibeProxyCore

/// Manager for the Rust core library integration
/// Provides Swift-friendly wrappers around the FFI functions
class RustCoreManager: ObservableObject {
    static let shared = RustCoreManager()
    
    @Published var isInitialized = false
    @Published var version: String = "unknown"
    @Published var backendHealth: HealthStatus?
    @Published var slmHealth: HealthStatus?
    
    private var healthCheckTimer: Timer?
    private let healthCheckInterval: TimeInterval = 30.0
    
    private init() {
        initialize()
    }
    
    /// Initialize the Rust core library
    func initialize() {
        guard !isInitialized else { return }
        
        if VibeProxyCore.initialize() {
            isInitialized = true
            version = VibeProxyCore.version
            NSLog("[RustCore] Initialized successfully, version: %@", version)
            startHealthChecks()
        } else {
            NSLog("[RustCore] Failed to initialize - library not found")
        }
    }
    
    /// Get the current configuration
    func getConfig() -> AppConfig {
        guard isInitialized else { return AppConfig() }
        
        switch VibeProxyCore.loadConfig() {
        case .success(let config):
            return config
        case .failure(let error):
            NSLog("[RustCore] Failed to load config: %@", error.localizedDescription)
            return VibeProxyCore.defaultConfig()
        }
    }
    
    /// Save configuration
    func saveConfig(_ config: AppConfig) -> Bool {
        guard isInitialized else { return false }
        
        switch VibeProxyCore.saveConfig(config) {
        case .success:
            NSLog("[RustCore] Config saved successfully")
            return true
        case .failure(let error):
            NSLog("[RustCore] Failed to save config: %@", error.localizedDescription)
            return false
        }
    }
    
    /// Check backend health
    func checkBackendHealth(config: BackendConfig? = nil) {
        guard isInitialized else { return }
        
        let backendConfig = config ?? getConfig().backend
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = VibeProxyCore.backendHealth(config: backendConfig)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self?.backendHealth = status
                    NSLog("[RustCore] Backend health: %@, latency: %dms", 
                          status.healthy ? "healthy" : "unhealthy", 
                          status.latencyMs)
                case .failure(let error):
                    self?.backendHealth = HealthStatus(healthy: false, latencyMs: 0, message: error.localizedDescription)
                    NSLog("[RustCore] Backend health check failed: %@", error.localizedDescription)
                }
            }
        }
    }
    
    /// Check SLM health
    func checkSLMHealth(config: SLMConfig? = nil) {
        guard isInitialized else { return }
        
        let slmConfig = config ?? getConfig().slm
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let result = VibeProxyCore.slmHealth(config: slmConfig)
            
            DispatchQueue.main.async {
                switch result {
                case .success(let status):
                    self?.slmHealth = status
                    NSLog("[RustCore] SLM health: %@, latency: %dms",
                          status.healthy ? "healthy" : "unhealthy",
                          status.latencyMs)
                case .failure(let error):
                    self?.slmHealth = HealthStatus(healthy: false, latencyMs: 0, message: error.localizedDescription)
                    NSLog("[RustCore] SLM health check failed: %@", error.localizedDescription)
                }
            }
        }
    }
    
    /// Start periodic health checks
    func startHealthChecks() {
        stopHealthChecks()
        
        // Initial check
        checkBackendHealth()
        checkSLMHealth()
        
        // Periodic checks
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            self?.checkBackendHealth()
            self?.checkSLMHealth()
        }
    }
    
    /// Stop periodic health checks
    func stopHealthChecks() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }
    
    deinit {
        stopHealthChecks()
    }
}

// MARK: - Configuration Helpers

extension RustCoreManager {
    /// Update backend configuration
    func updateBackendConfig(_ update: (inout BackendConfig) -> Void) -> Bool {
        var config = getConfig()
        update(&config.backend)
        return saveConfig(config)
    }
    
    /// Update SLM configuration
    func updateSLMConfig(_ update: (inout SLMConfig) -> Void) -> Bool {
        var config = getConfig()
        update(&config.slm)
        return saveConfig(config)
    }
    
    /// Update tunnel configuration
    func updateTunnelConfig(_ update: (inout TunnelConfig) -> Void) -> Bool {
        var config = getConfig()
        update(&config.tunnel)
        return saveConfig(config)
    }
    
    /// Update proxy configuration
    func updateProxyConfig(_ update: (inout ProxyConfig) -> Void) -> Bool {
        var config = getConfig()
        update(&config.proxy)
        return saveConfig(config)
    }
}

