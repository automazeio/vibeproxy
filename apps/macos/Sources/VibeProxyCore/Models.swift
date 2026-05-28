// Swift models matching Rust configuration types

import Foundation

// MARK: - Configuration Models

/// Main application configuration
public struct AppConfig: Codable {
    public var backend: BackendConfig
    public var slm: SLMConfig
    public var tunnel: TunnelConfig
    public var proxy: ProxyConfig
    
    public init(
        backend: BackendConfig = BackendConfig(),
        slm: SLMConfig = SLMConfig(),
        tunnel: TunnelConfig = TunnelConfig(),
        proxy: ProxyConfig = ProxyConfig()
    ) {
        self.backend = backend
        self.slm = slm
        self.tunnel = tunnel
        self.proxy = proxy
    }
}

/// Backend connection configuration
public struct BackendConfig: Codable {
    public var url: String
    public var port: UInt16
    public var apiKey: String?
    public var timeoutSecs: UInt64
    public var useConnect: Bool
    
    public init(
        url: String = "http://localhost",
        port: UInt16 = 8317,
        apiKey: String? = nil,
        timeoutSecs: UInt64 = 30,
        useConnect: Bool = false
    ) {
        self.url = url
        self.port = port
        self.apiKey = apiKey
        self.timeoutSecs = timeoutSecs
        self.useConnect = useConnect
    }
}

/// SLM backend type
public enum SLMBackend: String, Codable {
    case vllm
    case mlx
    case ollama
}

/// SLM server configuration
public struct SLMConfig: Codable {
    public var url: String
    public var port: UInt16
    public var backend: SLMBackend
    public var autoStart: Bool
    public var defaultModel: String
    
    public init(
        url: String = "http://localhost",
        port: UInt16 = 8318,
        backend: SLMBackend = .vllm,
        autoStart: Bool = false,
        defaultModel: String = "llama-3.2-3b"
    ) {
        self.url = url
        self.port = port
        self.backend = backend
        self.autoStart = autoStart
        self.defaultModel = defaultModel
    }
}

/// Tunnel configuration
public struct TunnelConfig: Codable {
    public var enabled: Bool
    public var tunnelId: String?
    public var credentialsPath: String?
    public var autoConnect: Bool
    
    public init(
        enabled: Bool = false,
        tunnelId: String? = nil,
        credentialsPath: String? = nil,
        autoConnect: Bool = false
    ) {
        self.enabled = enabled
        self.tunnelId = tunnelId
        self.credentialsPath = credentialsPath
        self.autoConnect = autoConnect
    }
}

/// Proxy configuration
public struct ProxyConfig: Codable {
    public var listenPort: UInt16
    public var enableThinkingProxy: Bool
    public var thinkingProxyPort: UInt16
    
    public init(
        listenPort: UInt16 = 8316,
        enableThinkingProxy: Bool = true,
        thinkingProxyPort: UInt16 = 8317
    ) {
        self.listenPort = listenPort
        self.enableThinkingProxy = enableThinkingProxy
        self.thinkingProxyPort = thinkingProxyPort
    }
}

// MARK: - Status Models

/// Health status of a service
public struct HealthStatus: Codable {
    public let healthy: Bool
    public let latencyMs: UInt64
    public let message: String?
    
    public init(healthy: Bool, latencyMs: UInt64, message: String? = nil) {
        self.healthy = healthy
        self.latencyMs = latencyMs
        self.message = message
    }
}

/// Model information
public struct ModelInfo: Codable {
    public let id: String
    public let name: String
    public let provider: String
    public let contextLength: UInt32?
    public let supportsStreaming: Bool
}

/// Backend status
public struct BackendStatus: Codable {
    public let version: String
    public let uptimeSecs: UInt64
    public let models: [ModelInfo]
    public let activeConnections: UInt32
}

/// SLM status
public struct SLMStatus: Codable {
    public let running: Bool
    public let model: String?
    public let memoryUsedMb: UInt64
    public let requestsServed: UInt64
}

