using System.ComponentModel;
using System.IO;
using System.Runtime.CompilerServices;
using System.Text.Json;
using VibeProxy.Models;

namespace VibeProxy.Services;

/// <summary>
/// Manages authentication status for all service providers.
/// Monitors the ~/.cli-proxy-api directory for credential changes.
/// Equivalent to AuthManager in the macOS version.
/// </summary>
public class AuthManager : INotifyPropertyChanged, IDisposable
{
    private readonly string _authDirectory;
    private FileSystemWatcher? _watcher;
    private readonly object _lock = new();
    private DateTime _lastRefresh = DateTime.MinValue;
    private const int RefreshDebounceMs = 500;
    private System.Threading.Timer? _debounceTimer;

    public event PropertyChangedEventHandler? PropertyChanged;
    public event Action? OnAuthStatusChanged;

    private Dictionary<ServiceType, ServiceAccounts> _serviceAccounts = new();

    public IReadOnlyDictionary<ServiceType, ServiceAccounts> ServiceAccounts => _serviceAccounts;

    public AuthManager()
    {
        _authDirectory = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
            ".cli-proxy-api");

        // Initialize accounts dictionary for all service types
        foreach (ServiceType service in Enum.GetValues<ServiceType>())
        {
            _serviceAccounts[service] = new ServiceAccounts { Service = service };
        }

        // Ensure directory exists
        if (!Directory.Exists(_authDirectory))
        {
            Directory.CreateDirectory(_authDirectory);
        }

        // Initial load
        RefreshAuthStatus();

        // Start file watcher
        StartFileWatcher();
    }

    /// <summary>
    /// Gets accounts for a specific service.
    /// </summary>
    public ServiceAccounts GetAccounts(ServiceType service)
    {
        return _serviceAccounts.TryGetValue(service, out var accounts)
            ? accounts
            : new ServiceAccounts { Service = service };
    }

    /// <summary>
    /// Checks if a service has any connected accounts.
    /// </summary>
    public bool HasAccounts(ServiceType service)
    {
        return _serviceAccounts.TryGetValue(service, out var accounts) && accounts.HasAccounts;
    }

    /// <summary>
    /// Refreshes authentication status from disk.
    /// </summary>
    public void RefreshAuthStatus()
    {
        lock (_lock)
        {
            // Reset all accounts
            foreach (var service in _serviceAccounts.Keys)
            {
                _serviceAccounts[service] = new ServiceAccounts { Service = service };
            }

            if (!Directory.Exists(_authDirectory)) return;

            try
            {
                var files = Directory.GetFiles(_authDirectory, "*.json");
                foreach (var file in files)
                {
                    try
                    {
                        var account = ParseAuthFile(file);
                        if (account != null && _serviceAccounts.TryGetValue(account.Type, out var serviceAccounts))
                        {
                            serviceAccounts.Accounts.Add(account);
                        }
                    }
                    catch
                    {
                        // Skip invalid files
                    }
                }
            }
            catch
            {
                // Directory read error
            }
        }

        OnPropertyChanged(nameof(ServiceAccounts));
        OnAuthStatusChanged?.Invoke();
    }

    /// <summary>
    /// Deletes an account's credential file.
    /// </summary>
    public bool DeleteAccount(AuthAccount account)
    {
        try
        {
            if (File.Exists(account.FilePath))
            {
                File.Delete(account.FilePath);
                // File watcher will trigger refresh
                return true;
            }
        }
        catch
        {
            // Deletion failed
        }
        return false;
    }

    /// <summary>
    /// Opens the auth directory in File Explorer.
    /// </summary>
    public void OpenAuthDirectory()
    {
        if (!Directory.Exists(_authDirectory))
        {
            Directory.CreateDirectory(_authDirectory);
        }

        System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = _authDirectory,
            UseShellExecute = true
        });
    }

    private AuthAccount? ParseAuthFile(string filePath)
    {
        var json = File.ReadAllText(filePath);
        using var doc = JsonDocument.Parse(json);
        var root = doc.RootElement;

        // Get type field
        if (!root.TryGetProperty("type", out var typeElement))
            return null;

        var type = typeElement.GetString();
        if (string.IsNullOrEmpty(type))
            return null;

        var serviceType = ServiceTypeExtensions.FromJsonType(type);
        if (serviceType == null)
            return null;

        var account = new AuthAccount
        {
            Id = Path.GetFileNameWithoutExtension(filePath),
            Type = serviceType.Value,
            FilePath = filePath
        };

        // Get email
        if (root.TryGetProperty("email", out var emailElement))
        {
            account.Email = emailElement.GetString();
        }

        // Get login (for Copilot)
        if (root.TryGetProperty("login", out var loginElement))
        {
            account.Login = loginElement.GetString();
        }

        // Get expiration
        if (root.TryGetProperty("expired", out var expiredElement))
        {
            if (expiredElement.TryGetDateTime(out var expiredDate))
            {
                account.Expired = expiredDate;
            }
            else if (expiredElement.ValueKind == JsonValueKind.String)
            {
                if (DateTime.TryParse(expiredElement.GetString(), out var parsed))
                {
                    account.Expired = parsed;
                }
            }
        }

        return account;
    }

    private void StartFileWatcher()
    {
        try
        {
            _watcher = new FileSystemWatcher(_authDirectory)
            {
                Filter = "*.json",
                NotifyFilter = NotifyFilters.FileName | NotifyFilters.LastWrite | NotifyFilters.CreationTime,
                EnableRaisingEvents = true
            };

            _watcher.Created += OnFileChanged;
            _watcher.Changed += OnFileChanged;
            _watcher.Deleted += OnFileChanged;
            _watcher.Renamed += OnFileRenamed;
        }
        catch
        {
            // File watcher failed, polling would be needed as fallback
        }
    }

    private void OnFileChanged(object sender, FileSystemEventArgs e)
    {
        DebouncedRefresh();
    }

    private void OnFileRenamed(object sender, RenamedEventArgs e)
    {
        DebouncedRefresh();
    }

    private void DebouncedRefresh()
    {
        // Cancel previous timer
        _debounceTimer?.Dispose();

        // Start new debounce timer
        _debounceTimer = new System.Threading.Timer(_ =>
        {
            RefreshAuthStatus();
        }, null, RefreshDebounceMs, Timeout.Infinite);
    }

    protected void OnPropertyChanged([CallerMemberName] string? propertyName = null)
    {
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
    }

    public void Dispose()
    {
        _watcher?.Dispose();
        _debounceTimer?.Dispose();
    }
}
