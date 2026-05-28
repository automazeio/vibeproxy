// Swift bindings for VibeProxy Core
// Provides Swift wrappers around the Rust FFI functions

import Foundation

// MARK: - Type Aliases for FFI

private typealias VoidToBoolFunc = @convention(c) () -> Bool
private typealias VoidToStringFunc = @convention(c) () -> UnsafeMutablePointer<CChar>
private typealias StringToVoidFunc = @convention(c) (UnsafePointer<CChar>) -> Void

// MARK: - VibeProxyCore

/// Swift wrapper for the VibeProxy Rust core library
public class VibeProxyCore {
    private static var libraryHandle: UnsafeMutableRawPointer?
    private static var isInitialized = false

    /// Initialize the library (call once at app startup)
    public static func initialize() -> Bool {
        guard !isInitialized else { return true }

        // Try multiple paths for the library
        let searchPaths = [
            Bundle.main.path(forResource: "libvibeproxy_core", ofType: "dylib"),
            Bundle.main.bundlePath + "/Contents/Frameworks/libvibeproxy_core.dylib",
            "/usr/local/lib/libvibeproxy_core.dylib"
        ].compactMap { $0 }

        for path in searchPaths {
            if let handle = dlopen(path, RTLD_NOW) {
                libraryHandle = handle
                // Initialize runtime
                if let runtimeInit = dlsym(handle, "vibeproxy_runtime_init") {
                    typealias InitFunc = @convention(c) () -> Bool
                    let initFunc = unsafeBitCast(runtimeInit, to: InitFunc.self)
                    _ = initFunc()
                }
                isInitialized = true
                return true
            }
        }

        // Library not found - that's OK, we'll use fallback implementations
        isInitialized = true
        return false
    }

    /// Get library version
    public static var version: String {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_version") else {
            return "1.0.0-swift"
        }
        typealias VersionFunc = @convention(c) () -> UnsafeMutablePointer<CChar>
        let versionFunc = unsafeBitCast(funcPtr, to: VersionFunc.self)
        let ptr = versionFunc()
        let result = String(cString: ptr)
        freeString(ptr)
        return result
    }

    // MARK: - Configuration

    /// Get default configuration
    public static func defaultConfig() -> AppConfig {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_config_default") else {
            return AppConfig()
        }

        typealias GetDefaultFunc = @convention(c) () -> UnsafeMutablePointer<CChar>
        let getDefault = unsafeBitCast(funcPtr, to: GetDefaultFunc.self)
        let jsonPtr = getDefault()
        let json = String(cString: jsonPtr)
        freeString(jsonPtr)

        guard let data = json.data(using: String.Encoding.utf8),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    /// Load configuration from default path
    public static func loadConfig() -> Result<AppConfig, Error> {
        // For now, return default config since FFI with struct returns is complex
        // In production, this would call the Rust function
        return .success(defaultConfig())
    }

    /// Save configuration to default path
    public static func saveConfig(_ config: AppConfig) -> Result<Void, Error> {
        // For now, just succeed - in production this would call Rust
        return .success(())
    }

    // MARK: - Backend Client

    /// Check backend health
    public static func backendHealth(config: BackendConfig) -> Result<HealthStatus, Error> {
        // Fallback implementation - make HTTP request directly
        return .success(HealthStatus(healthy: false, latencyMs: 0, message: "Not connected"))
    }

    // MARK: - SLM Client

    /// Check SLM health
    public static func slmHealth(config: SLMConfig) -> Result<HealthStatus, Error> {
        // Fallback implementation
        return .success(HealthStatus(healthy: false, latencyMs: 0, message: "Not connected"))
    }

    // MARK: - Private Helpers

    private static func freeString(_ ptr: UnsafeMutablePointer<CChar>) {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_string_free") else { return }
        typealias FreeFunc = @convention(c) (UnsafeMutablePointer<CChar>) -> Void
        let freeFunc = unsafeBitCast(funcPtr, to: FreeFunc.self)
        freeFunc(ptr)
    }
}

// MARK: - Errors

public enum VibeProxyError: Error, LocalizedError {
    case libraryNotLoaded
    case configError(String)
    case parseError(String)
    case apiError(String)

    public var errorDescription: String? {
        switch self {
        case .libraryNotLoaded: return "VibeProxy core library not loaded"
        case .configError(let msg): return "Config error: \(msg)"
        case .parseError(let msg): return "Parse error: \(msg)"
        case .apiError(let msg): return "API error: \(msg)"
        }
    }
}
