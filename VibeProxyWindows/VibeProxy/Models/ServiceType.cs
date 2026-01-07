namespace VibeProxy.Models;

/// <summary>
/// Supported authentication service types.
/// Maps to the macOS ServiceType enum.
/// </summary>
public enum ServiceType
{
    Claude,
    Codex,
    Copilot,
    Gemini,
    Qwen,
    Antigravity
}

public static class ServiceTypeExtensions
{
    /// <summary>
    /// Gets the display name for the service.
    /// </summary>
    public static string GetDisplayName(this ServiceType service) => service switch
    {
        ServiceType.Claude => "Claude",
        ServiceType.Codex => "Codex",
        ServiceType.Copilot => "GitHub Copilot",
        ServiceType.Gemini => "Gemini",
        ServiceType.Qwen => "Qwen",
        ServiceType.Antigravity => "Antigravity",
        _ => service.ToString()
    };

    /// <summary>
    /// Gets the file prefix used in auth JSON files.
    /// </summary>
    public static string GetFilePrefix(this ServiceType service) => service switch
    {
        ServiceType.Claude => "claude",
        ServiceType.Codex => "codex",
        ServiceType.Copilot => "github-copilot",
        ServiceType.Gemini => "gemini",
        ServiceType.Qwen => "qwen",
        ServiceType.Antigravity => "antigravity",
        _ => service.ToString().ToLowerInvariant()
    };

    /// <summary>
    /// Parses a service type from the JSON file's "type" field.
    /// </summary>
    public static ServiceType? FromJsonType(string type)
    {
        return type.ToLowerInvariant() switch
        {
            "claude" => ServiceType.Claude,
            "codex" => ServiceType.Codex,
            "github-copilot" => ServiceType.Copilot,
            "gemini" => ServiceType.Gemini,
            "qwen" => ServiceType.Qwen,
            "antigravity" => ServiceType.Antigravity,
            _ => null
        };
    }

    /// <summary>
    /// Gets the icon filename for the service.
    /// </summary>
    public static string GetIconName(this ServiceType service) => service switch
    {
        ServiceType.Claude => "icon-claude.png",
        ServiceType.Codex => "icon-codex.png",
        ServiceType.Copilot => "icon-copilot.png",
        ServiceType.Gemini => "icon-gemini.png",
        ServiceType.Qwen => "icon-qwen.png",
        ServiceType.Antigravity => "icon-antigravity.png",
        _ => "glyph.png"
    };
}
