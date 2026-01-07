namespace VibeProxy.Models;

/// <summary>
/// Represents an authenticated account for a service provider.
/// Maps to the macOS AuthAccount struct.
/// </summary>
public class AuthAccount
{
    /// <summary>
    /// Unique identifier (typically the filename without extension).
    /// </summary>
    public string Id { get; set; } = "";

    /// <summary>
    /// Email address associated with the account (if available).
    /// </summary>
    public string? Email { get; set; }

    /// <summary>
    /// Username/login (used by GitHub Copilot).
    /// </summary>
    public string? Login { get; set; }

    /// <summary>
    /// The service type this account belongs to.
    /// </summary>
    public ServiceType Type { get; set; }

    /// <summary>
    /// Expiration date of the authentication token (if applicable).
    /// </summary>
    public DateTime? Expired { get; set; }

    /// <summary>
    /// Full path to the JSON credential file.
    /// </summary>
    public string FilePath { get; set; } = "";

    /// <summary>
    /// Whether the account's credentials have expired.
    /// </summary>
    public bool IsExpired => Expired.HasValue && Expired.Value < DateTime.UtcNow;

    /// <summary>
    /// Display name for the account (email, login, or ID).
    /// </summary>
    public string DisplayName => Email ?? Login ?? Id;

    public override string ToString() => $"{Type.GetDisplayName()}: {DisplayName}";
}

/// <summary>
/// Container for accounts of a specific service.
/// </summary>
public class ServiceAccounts
{
    public ServiceType Service { get; set; }
    public List<AuthAccount> Accounts { get; set; } = new();

    public bool HasAccounts => Accounts.Count > 0;
    public bool HasExpiredAccounts => Accounts.Any(a => a.IsExpired);
    public int Count => Accounts.Count;
}
