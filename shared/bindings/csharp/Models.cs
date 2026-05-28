// C# models matching Rust configuration types

using System.Text.Json.Serialization;

namespace VibeProxyCore;

#region Configuration Models

/// <summary>
/// Main application configuration
/// </summary>
public class AppConfig
{
    public BackendConfig Backend { get; set; } = new();
    public SLMConfig Slm { get; set; } = new();
    public TunnelConfig Tunnel { get; set; } = new();
    public ProxyConfig Proxy { get; set; } = new();
}

/// <summary>
/// Backend connection configuration
/// </summary>
public class BackendConfig
{
    public string Url { get; set; } = "http://localhost";
    public ushort Port { get; set; } = 8317;
    public string? ApiKey { get; set; }
    public ulong TimeoutSecs { get; set; } = 30;
    public bool UseConnect { get; set; } = false;
}

/// <summary>
/// SLM backend type
/// </summary>
[JsonConverter(typeof(JsonStringEnumConverter))]
public enum SLMBackend
{
    Vllm,
    Mlx,
    Ollama
}

/// <summary>
/// SLM server configuration
/// </summary>
public class SLMConfig
{
    public string Url { get; set; } = "http://localhost";
    public ushort Port { get; set; } = 8318;
    public SLMBackend Backend { get; set; } = SLMBackend.Vllm;
    public bool AutoStart { get; set; } = false;
    public string DefaultModel { get; set; } = "llama-3.2-3b";
}

/// <summary>
/// Tunnel configuration
/// </summary>
public class TunnelConfig
{
    public bool Enabled { get; set; } = false;
    public string? TunnelId { get; set; }
    public string? CredentialsPath { get; set; }
    public bool AutoConnect { get; set; } = false;
}

/// <summary>
/// Proxy configuration
/// </summary>
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

/// <summary>
/// Model information
/// </summary>
public class ModelInfo
{
    public string Id { get; set; } = "";
    public string Name { get; set; } = "";
    public string Provider { get; set; } = "";
    public uint? ContextLength { get; set; }
    public bool SupportsStreaming { get; set; }
}

/// <summary>
/// Backend status
/// </summary>
public class BackendStatus
{
    public string Version { get; set; } = "";
    public ulong UptimeSecs { get; set; }
    public ModelInfo[] Models { get; set; } = Array.Empty<ModelInfo>();
    public uint ActiveConnections { get; set; }
}

/// <summary>
/// SLM status
/// </summary>
public class SLMStatus
{
    public bool Running { get; set; }
    public string? Model { get; set; }
    public ulong MemoryUsedMb { get; set; }
    public ulong RequestsServed { get; set; }
}

#endregion

