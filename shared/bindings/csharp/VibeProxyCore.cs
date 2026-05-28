using System;
using System.Runtime.InteropServices;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace VibeProxyCore;

#region FFI Types

[StructLayout(LayoutKind.Sequential)]
internal struct FFIResult
{
    [MarshalAs(UnmanagedType.I1)]
    public bool Success;
    public IntPtr Data;
    public IntPtr Error;
}

#endregion

/// <summary>
/// C# bindings for VibeProxy Rust core library
/// </summary>
public static class VibeProxyCore
{
    private const string DllName = "vibeproxy_core";
    private static bool _initialized = false;

    #region Native Imports

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr vibeproxy_config_default();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void vibeproxy_string_free(IntPtr str);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern void vibeproxy_result_free(FFIResult result);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern FFIResult vibeproxy_config_load();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern FFIResult vibeproxy_config_save(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string json);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern FFIResult vibeproxy_backend_health(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string configJson);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern FFIResult vibeproxy_slm_health(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string configJson);

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    [return: MarshalAs(UnmanagedType.I1)]
    private static extern bool vibeproxy_runtime_init();

    [DllImport(DllName, CallingConvention = CallingConvention.Cdecl)]
    private static extern IntPtr vibeproxy_version();

    #endregion

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull
    };

    /// <summary>
    /// Initialize the library (call once at app startup)
    /// </summary>
    public static bool Initialize()
    {
        if (_initialized) return true;
        _initialized = vibeproxy_runtime_init();
        return _initialized;
    }

    /// <summary>
    /// Get library version
    /// </summary>
    public static string Version
    {
        get
        {
            IntPtr ptr = vibeproxy_version();
            try { return Marshal.PtrToStringUTF8(ptr) ?? "unknown"; }
            finally { vibeproxy_string_free(ptr); }
        }
    }

    /// <summary>
    /// Get default configuration
    /// </summary>
    public static AppConfig GetDefaultConfig()
    {
        IntPtr jsonPtr = vibeproxy_config_default();
        if (jsonPtr == IntPtr.Zero) return new AppConfig();
        try
        {
            string json = Marshal.PtrToStringUTF8(jsonPtr) ?? "{}";
            return JsonSerializer.Deserialize<AppConfig>(json, JsonOptions) ?? new AppConfig();
        }
        finally { vibeproxy_string_free(jsonPtr); }
    }

    /// <summary>
    /// Load configuration from default path
    /// </summary>
    public static AppConfig LoadConfig()
    {
        FFIResult result = vibeproxy_config_load();
        try
        {
            if (result.Success)
            {
                string json = Marshal.PtrToStringUTF8(result.Data) ?? "{}";
                return JsonSerializer.Deserialize<AppConfig>(json, JsonOptions) ?? new AppConfig();
            }
            string error = Marshal.PtrToStringUTF8(result.Error) ?? "Unknown error";
            throw new VibeProxyException($"Failed to load config: {error}");
        }
        finally { vibeproxy_result_free(result); }
    }

    /// <summary>
    /// Save configuration to default path
    /// </summary>
    public static void SaveConfig(AppConfig config)
    {
        string json = JsonSerializer.Serialize(config, JsonOptions);
        FFIResult result = vibeproxy_config_save(json);
        try
        {
            if (!result.Success)
            {
                string error = Marshal.PtrToStringUTF8(result.Error) ?? "Unknown error";
                throw new VibeProxyException($"Failed to save config: {error}");
            }
        }
        finally { vibeproxy_result_free(result); }
    }

    /// <summary>
    /// Check backend health
    /// </summary>
    public static HealthStatus CheckBackendHealth(BackendConfig config)
    {
        string json = JsonSerializer.Serialize(config, JsonOptions);
        FFIResult result = vibeproxy_backend_health(json);
        try
        {
            if (result.Success)
            {
                string data = Marshal.PtrToStringUTF8(result.Data) ?? "{}";
                return JsonSerializer.Deserialize<HealthStatus>(data, JsonOptions) ?? new HealthStatus();
            }
            string error = Marshal.PtrToStringUTF8(result.Error) ?? "Unknown error";
            throw new VibeProxyException($"Health check failed: {error}");
        }
        finally { vibeproxy_result_free(result); }
    }

    /// <summary>
    /// Check SLM health
    /// </summary>
    public static HealthStatus CheckSLMHealth(SLMConfig config)
    {
        string json = JsonSerializer.Serialize(config, JsonOptions);
        FFIResult result = vibeproxy_slm_health(json);
        try
        {
            if (result.Success)
            {
                string data = Marshal.PtrToStringUTF8(result.Data) ?? "{}";
                return JsonSerializer.Deserialize<HealthStatus>(data, JsonOptions) ?? new HealthStatus();
            }
            string error = Marshal.PtrToStringUTF8(result.Error) ?? "Unknown error";
            throw new VibeProxyException($"Health check failed: {error}");
        }
        finally { vibeproxy_result_free(result); }
    }
}

#region Configuration Models

/// <summary>
/// Application configuration matching Rust structs
/// </summary>
public class AppConfig
{
    public BackendConfig Backend { get; set; } = new();
    public SLMConfig SLM { get; set; } = new();
    public TunnelConfig Tunnel { get; set; } = new();
    public ProxyConfig Proxy { get; set; } = new();
}

public class BackendConfig
{
    public string Url { get; set; } = "http://localhost";
    public ushort Port { get; set; } = 8317;
    public string? ApiKey { get; set; }
    public ulong TimeoutSecs { get; set; } = 30;
    public bool UseConnect { get; set; } = false;
}

public class SLMConfig
{
    public string Url { get; set; } = "http://localhost";
    public ushort Port { get; set; } = 8318;
    public string Backend { get; set; } = "vllm";
    public bool AutoStart { get; set; } = false;
    public string DefaultModel { get; set; } = "llama-3.2-3b";
}

public class TunnelConfig
{
    public bool Enabled { get; set; } = false;
    public string? TunnelId { get; set; }
    public string? CredentialsPath { get; set; }
    public bool AutoConnect { get; set; } = false;
}

public class ProxyConfig
{
    public ushort ListenPort { get; set; } = 8316;
    public bool EnableThinkingProxy { get; set; } = true;
    public ushort ThinkingProxyPort { get; set; } = 8317;
}

#endregion

#region Status Models

/// <summary>
/// Health status of a service
/// </summary>
public class HealthStatus
{
    public bool Healthy { get; set; }
    public ulong LatencyMs { get; set; }
    public string? Message { get; set; }
}

#endregion

#region Exceptions

public class VibeProxyException : Exception
{
    public VibeProxyException(string message) : base(message) { }
}

#endregion
