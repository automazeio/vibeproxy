// Swift bindings for VibeProxy Core
// Provides Swift wrappers around the Rust FFI functions

import Foundation

// MARK: - FFI Types

/// Result from FFI operations
public struct FFIResult {
    public let success: Bool
    public let data: String?
    public let error: String?
}

// MARK: - VibeProxyCore

/// Swift wrapper for the VibeProxy Rust core library
public class VibeProxyCore {
    private static var libraryHandle: UnsafeMutableRawPointer?

    /// Initialize the library (call once at app startup)
    public static func initialize() -> Bool {
        guard libraryHandle == nil else { return true }

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
                    let initFunc: @convention(c) () -> Bool = unsafeBitCast(runtimeInit, to: type(of: initFunc))
                    _ = initFunc()
                }
                return true
            }
        }
        return false
    }

    /// Get library version
    public static var version: String {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_version") else {
            return "unknown"
        }
        let versionFunc: @convention(c) () -> UnsafeMutablePointer<CChar> = unsafeBitCast(funcPtr, to: type(of: versionFunc))
        let ptr = versionFunc()
        defer { freeString(ptr) }
        return String(cString: ptr)
    }

    // MARK: - Configuration

    /// Get default configuration
    public static func defaultConfig() -> AppConfig {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_config_default") else {
            return AppConfig()
        }

        let getDefault: @convention(c) () -> UnsafeMutablePointer<CChar> = unsafeBitCast(funcPtr, to: type(of: getDefault))
        let jsonPtr = getDefault()
        defer { freeString(jsonPtr) }

        let json = String(cString: jsonPtr)
        return (try? JSONDecoder().decode(AppConfig.self, from: json.data(using: .utf8)!)) ?? AppConfig()
    }

    /// Load configuration from default path
    public static func loadConfig() -> Result<AppConfig, Error> {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_config_load") else {
            return .failure(VibeProxyError.libraryNotLoaded)
        }

        let loadFunc: @convention(c) () -> FFIResultC = unsafeBitCast(funcPtr, to: type(of: loadFunc))
        let result = loadFunc()
        defer { freeResult(result) }

        if result.success {
            let json = String(cString: result.data)
            if let config = try? JSONDecoder().decode(AppConfig.self, from: json.data(using: .utf8)!) {
                return .success(config)
            }
            return .failure(VibeProxyError.parseError("Failed to decode config"))
        } else {
            let error = String(cString: result.error)
            return .failure(VibeProxyError.configError(error))
        }
    }

    /// Save configuration to default path
    public static func saveConfig(_ config: AppConfig) -> Result<Void, Error> {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_config_save"),
              let json = try? JSONEncoder().encode(config),
              let jsonString = String(data: json, encoding: .utf8) else {
            return .failure(VibeProxyError.libraryNotLoaded)
        }

        let saveFunc: @convention(c) (UnsafePointer<CChar>) -> FFIResultC = unsafeBitCast(funcPtr, to: type(of: saveFunc))
        let result = jsonString.withCString { saveFunc($0) }
        defer { freeResult(result) }

        if result.success {
            return .success(())
        } else {
            let error = String(cString: result.error)
            return .failure(VibeProxyError.configError(error))
        }
    }

    // MARK: - Backend Client

    /// Check backend health
    public static func backendHealth(config: BackendConfig) -> Result<HealthStatus, Error> {
        return callFFI(
            function: "vibeproxy_backend_health",
            config: config,
            responseType: HealthStatus.self
        )
    }

    // MARK: - SLM Client

    /// Check SLM health
    public static func slmHealth(config: SLMConfig) -> Result<HealthStatus, Error> {
        return callFFI(
            function: "vibeproxy_slm_health",
            config: config,
            responseType: HealthStatus.self
        )
    }

    // MARK: - Private Helpers

    private static func callFFI<T: Encodable, R: Decodable>(
        function: String,
        config: T,
        responseType: R.Type
    ) -> Result<R, Error> {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, function),
              let json = try? JSONEncoder().encode(config),
              let jsonString = String(data: json, encoding: .utf8) else {
            return .failure(VibeProxyError.libraryNotLoaded)
        }

        let ffiFunc: @convention(c) (UnsafePointer<CChar>) -> FFIResultC = unsafeBitCast(funcPtr, to: type(of: ffiFunc))
        let result = jsonString.withCString { ffiFunc($0) }
        defer { freeResult(result) }

        if result.success {
            let data = String(cString: result.data)
            if let response = try? JSONDecoder().decode(R.self, from: data.data(using: .utf8)!) {
                return .success(response)
            }
            return .failure(VibeProxyError.parseError("Failed to decode response"))
        } else {
            let error = String(cString: result.error)
            return .failure(VibeProxyError.apiError(error))
        }
    }

    private static func freeString(_ ptr: UnsafeMutablePointer<CChar>) {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_string_free") else { return }
        let freeFunc: @convention(c) (UnsafeMutablePointer<CChar>) -> Void = unsafeBitCast(funcPtr, to: type(of: freeFunc))
        freeFunc(ptr)
    }

    private static func freeResult(_ result: FFIResultC) {
        guard let handle = libraryHandle,
              let funcPtr = dlsym(handle, "vibeproxy_result_free") else { return }
        let freeFunc: @convention(c) (FFIResultC) -> Void = unsafeBitCast(funcPtr, to: type(of: freeFunc))
        freeFunc(result)
    }
}

// MARK: - C Types

private struct FFIResultC {
    let success: Bool
    let data: UnsafeMutablePointer<CChar>
    let error: UnsafeMutablePointer<CChar>
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
